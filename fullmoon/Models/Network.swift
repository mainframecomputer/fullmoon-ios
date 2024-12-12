//
//  Network.swift
//  fullmoon
//
//  Created by Jordan Singer on 12/11/24.
//

import SwiftUI
import Foundation
import Network
import MLX
import MLXLLM

let SERVICE_TYPE = "_fullmoon._tcp"

func getFriendlyName(from endpoint: NWEndpoint) -> String {
    if case .service(let name, _, _, _) = endpoint {
        return name
    }
    return endpoint.debugDescription
}

// Add message type enum before BonjourServiceAdvertiser class
enum MessageType: String, Codable {
    case clientName = "CLIENT_NAME"
    case heartbeat = "HEARTBEAT"
    case clientDisconnect = "CLIENT_DISCONNECT"
    case prompt = "PROMPT"
    case response = "RESPONSE"
}

typealias ChatMessage = [String: String]

struct PromptMessage: Codable {
    let type: String
    let promptHistory: [[String: String]]
    let modelName: String
}

struct ResponseMessage: Codable {
    let type: String
    let text: String
    let isComplete: Bool
}

class BonjourServiceAdvertiser: NSObject, ObservableObject {
    private var listener: NWListener?
    private var activeConnections: [String: ClientConnection] = [:]
    weak var appManager: AppManager?
    private var connectionMonitorTimer: Timer?
    
    struct ClientConnection {
        let connection: NWConnection
        var name: String?
        var lastHeartbeat: Date
    }
    
    private var deviceName: String {
        #if os(macOS)
        return Host.current().localizedName ?? "Mac"
        #else
        return UIDevice.current.name
        #endif
    }
    
    override init() {
        super.init()
        startConnectionMonitoring()
    }
    
    func startAdvertising() {
        stopAdvertising()
        
        do {
            listener = try NWListener(using: .tcp)
            listener?.service = NWListener.Service(name: deviceName, type: SERVICE_TYPE)
            
            listener?.stateUpdateHandler = { [weak self] state in
                switch state {
                case .ready:
                    print("Server ready to accept connections")
                case .failed(let error):
                    print("Server failed: \(error)")
                    self?.restartAdvertising()
                default:
                    break
                }
            }
            
            listener?.newConnectionHandler = { [weak self] connection in
                self?.handleNewConnection(connection)
            }
            
            listener?.start(queue: .main)
        } catch {
            print("Failed to start server: \(error)")
        }
    }
    
    func stopAdvertising() {
        listener?.cancel()
        listener = nil
        activeConnections.values.forEach { $0.connection.cancel() }
        activeConnections.removeAll()
    }
    
    private func restartAdvertising() {
        listener?.cancel()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.startAdvertising()
        }
    }

    private func startConnectionMonitoring() {
        connectionMonitorTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.checkConnections()
        }
    }
    
    private func checkConnections() {
        let staleThreshold = Date().addingTimeInterval(-15) // 15 seconds without heartbeat
        
        for (id, client) in activeConnections {
            if client.lastHeartbeat < staleThreshold {
                removeConnection(id)
            }
        }
    }
    
    private func removeConnection(_ id: String) {
        if let client = activeConnections[id] {
            if let clientName = client.name {
                DispatchQueue.main.async { [weak self] in
                    self?.appManager?.removeConnectedClient(clientName)
                    print("Client disconnected: \(clientName)")
                }
            }
            client.connection.cancel()
            activeConnections.removeValue(forKey: id)
        }
    }

    private func handleNewConnection(_ connection: NWConnection) {
        let connectionId = UUID().uuidString
        
        // Initialize connection without name
        activeConnections[connectionId] = ClientConnection(
            connection: connection,
            name: nil,
            lastHeartbeat: Date()
        )
        
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                print("Client connection ready")
            case .failed, .cancelled:
                DispatchQueue.main.async {
                    self?.removeConnection(connectionId)
                }
            default:
                break
            }
        }
        
        startReceiving(connection, connectionId)
        connection.start(queue: .main)
    }
    
    private func startReceiving(_ connection: NWConnection, _ connectionId: String) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, _, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Receive error: \(error)")
                self.removeConnection(connectionId)
                return
            }
            
            if let data = data,
               let message = String(data: data, encoding: .utf8) {
                self.handleMessage(message, connectionId: connectionId)
            }
            
            // Continue receiving
            self.startReceiving(connection, connectionId)
        }
    }
    
    private func handleMessage(_ message: String, connectionId: String) {
        // Update last heartbeat
        activeConnections[connectionId]?.lastHeartbeat = Date()
        
        if message.hasPrefix("\(MessageType.clientName.rawValue):") {
            let clientName = String(message.dropFirst("\(MessageType.clientName.rawValue):".count))
            
            // Prevent self-connection
            if clientName == deviceName {
                removeConnection(connectionId)
                return
            }
            
            DispatchQueue.main.async { [weak self] in
                self?.activeConnections[connectionId]?.name = clientName
                self?.appManager?.addConnectedClient(clientName)
            }
        } else if message == MessageType.heartbeat.rawValue {
            // Handle heartbeat
        } else if message == MessageType.clientDisconnect.rawValue {
            removeConnection(connectionId)
        } else {
            // Try to decode as a prompt message
            if let data = message.data(using: .utf8),
               let promptMessage = try? JSONDecoder().decode(PromptMessage.self, from: data) {
                handlePromptMessage(promptMessage, connectionId: connectionId)
            }
        }
    }
    
    private func handlePromptMessage(_ promptMessage: PromptMessage, connectionId: String) {
        guard let connection = activeConnections[connectionId]?.connection else { return }
        
        Task {
            do {
                let evaluator = await LLMEvaluator(appManager: appManager!)
                
                // Load the requested model
                let modelContainer = try await evaluator.load(modelName: promptMessage.modelName)
                
                // Get prompt tokens
                let promptTokens = try await modelContainer.perform { _, tokenizer in
                    try tokenizer.applyChatTemplate(messages: promptMessage.promptHistory)
                }
                
                // Capture generate parameters and max tokens before async context
                let generateParams = await evaluator.generateParameters
                let maxTokens = await evaluator.maxTokens
                let displayEveryNTokens = await evaluator.displayEveryNTokens
                let extraEOSTokens = await evaluator.modelConfiguration.extraEOSTokens
                
                // Generate with streaming
                await modelContainer.perform { model, tokenizer in
                    MLXLLM.generate(
                        promptTokens: promptTokens,
                        parameters: generateParams,
                        model: model,
                        tokenizer: tokenizer,
                        extraEOSTokens: extraEOSTokens
                    ) { tokens in
                        if tokens.count % displayEveryNTokens == 0 {
                            let text = tokenizer.decode(tokens: tokens)
                            
                            // Send streaming response
                            let response = ResponseMessage(
                                type: MessageType.response.rawValue,
                                text: text,
                                isComplete: false
                            )
                            
                            if let responseData = try? JSONEncoder().encode(response),
                               let responseString = String(data: responseData, encoding: .utf8) {
                                connection.send(content: responseString.data(using: .utf8)!, completion: .contentProcessed { _ in })
                            }
                        }
                        
                        return tokens.count >= maxTokens ? .stop : .more
                    }
                }
                
                // Send completion message
                let finalResponse = ResponseMessage(
                    type: MessageType.response.rawValue,
                    text: "",
                    isComplete: true
                )
                
                if let responseData = try? JSONEncoder().encode(finalResponse),
                   let responseString = String(data: responseData, encoding: .utf8) {
                    connection.send(content: responseString.data(using: .utf8)!, completion: .contentProcessed { _ in })
                }
                
            } catch {
                print("Error handling prompt: \(error)")
            }
        }
    }
    
    deinit {
        connectionMonitorTimer?.invalidate()
        activeConnections.values.forEach { $0.connection.cancel() }
        listener?.cancel()
    }
}

class BonjourClient: ObservableObject {
    var connection: NWConnection?
    private var heartbeatTimer: Timer?
    private var serviceName: String?
    
    private var deviceName: String {
        #if os(macOS)
        return Host.current().localizedName ?? "Mac"
        #else
        return UIDevice.current.name
        #endif
    }
    
    func connectToService(endpoint: NWEndpoint, completion: @escaping (Bool, String?) -> Void) {
        if case .service(let name, _, _, _) = endpoint {
            self.serviceName = name
        }
        
        connection = NWConnection(to: endpoint, using: .tcp)
        
        connection?.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                self?.sendInitialMessage(completion: completion)
                self?.startHeartbeat()
            case .failed(let error):
                print("Connection failed: \(error)")
                completion(false, nil)
            case .cancelled:
                completion(false, nil)
            default:
                break
            }
        }
        
        connection?.start(queue: .main)
    }
    
    private func sendInitialMessage(completion: @escaping (Bool, String?) -> Void) {
        guard let name = serviceName else {
            completion(false, nil)
            return
        }
        
        let nameMessage = "CLIENT_NAME:\(deviceName)".data(using: .utf8)!
        connection?.send(content: nameMessage, completion: .contentProcessed { _ in
            completion(true, name)
        })
    }
    
    private func startHeartbeat() {
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.sendHeartbeat()
        }
    }
    
    private func sendHeartbeat() {
        let heartbeat = "HEARTBEAT".data(using: .utf8)!
        connection?.send(content: heartbeat, completion: .contentProcessed { _ in })
    }
    
    func disconnect() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
        
        if let connection = connection {
            let disconnectMessage = "CLIENT_DISCONNECT".data(using: .utf8)!
            connection.send(content: disconnectMessage, completion: .contentProcessed { [weak self] _ in
                self?.connection?.cancel()
                self?.connection = nil
            })
        }
    }
    
    deinit {
        disconnect()
    }
}

class BonjourServiceBrowser: ObservableObject {
    @Published var discoveredServices: [NWEndpoint] = []
    private var browser: NWBrowser?
    private var activeServices: Set<NWEndpoint> = []
    
    init() {
        startBrowsing()
    }
    
    private func startBrowsing() {
        let parameters = NWParameters()
        parameters.includePeerToPeer = true
        
        // Clear existing services when starting/restarting browser
        activeServices.removeAll()
        discoveredServices.removeAll()
        
        browser = NWBrowser(for: .bonjour(type: SERVICE_TYPE, domain: nil), using: parameters)
        
        browser?.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                print("Browser ready")
            case .failed(let error):
                print("Browser failed: \(error)")
                self?.restartBrowsing()
            case .cancelled:
                // Clear services when browser is cancelled
                DispatchQueue.main.async {
                    self?.activeServices.removeAll()
                    self?.discoveredServices.removeAll()
                }
            default:
                break
            }
        }
        
        browser?.browseResultsChangedHandler = { [weak self] results, changes in
            DispatchQueue.main.async {
                // Reset active services to match current results
                self?.activeServices.removeAll()
                
                // Only add currently available services
                for result in results where result.interfaces.isEmpty == false {
                    self?.activeServices.insert(result.endpoint)
                }
                
                // Update discoveredServices with only active services
                self?.discoveredServices = Array(self?.activeServices ?? [])
            }
        }
        
        browser?.start(queue: .main)
    }
    
    private func restartBrowsing() {
        browser?.cancel()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.startBrowsing()
        }
    }
    
    deinit {
        browser?.cancel()
    }
}

