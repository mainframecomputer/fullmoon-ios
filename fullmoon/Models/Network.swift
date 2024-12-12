//
//  Network.swift
//  fullmoon
//
//  Created by Jordan Singer on 12/11/24.
//

import SwiftUI
import Foundation
import Network

let SERVICE_TYPE = "_fullmoon._tcp"

func getFriendlyName(from endpoint: NWEndpoint) -> String {
    if case .service(let name, _, _, _) = endpoint {
        return name
    }
    return endpoint.debugDescription
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
        
        if message.hasPrefix("CLIENT_NAME:") {
            let clientName = String(message.dropFirst("CLIENT_NAME:".count))
            
            // Prevent self-connection
            if clientName == deviceName {
                removeConnection(connectionId)
                return
            }
            
            DispatchQueue.main.async { [weak self] in
                self?.activeConnections[connectionId]?.name = clientName
                self?.appManager?.addConnectedClient(clientName)
            }
        } else if message == "HEARTBEAT" {
            // Handle heartbeat
        } else if message == "CLIENT_DISCONNECT" {
            removeConnection(connectionId)
        }
    }
    
    deinit {
        connectionMonitorTimer?.invalidate()
        activeConnections.values.forEach { $0.connection.cancel() }
        listener?.cancel()
    }
}

class BonjourClient: ObservableObject {
    private var connection: NWConnection?
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
    
    init() {
        startBrowsing()
    }
    
    private func startBrowsing() {
        let parameters = NWParameters()
        parameters.includePeerToPeer = true
        
        browser = NWBrowser(for: .bonjour(type: SERVICE_TYPE, domain: nil), using: parameters)
        
        browser?.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                print("Browser ready")
            case .failed(let error):
                print("Browser failed: \(error)")
                self?.restartBrowsing()
            default:
                break
            }
        }
        
        browser?.browseResultsChangedHandler = { [weak self] results, _ in
            DispatchQueue.main.async {
                self?.discoveredServices = results.map(\.endpoint)
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

