//
//  Server.swift
//  fullmoon
//
//  Created by Jordan Singer on 12/15/24.
//

import Foundation
import Network

class HTTPServer: ObservableObject {
    private var listener: NWListener?
    
    func start(port: UInt16) {
        do {
            // Create a TCP listener
            let parameters = NWParameters.tcp
            listener = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: port)!)
            
            listener?.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    print("HTTP Server is ready on port \(port)")
                case .failed(let error):
                    print("HTTP Server failed with error: \(error)")
                default:
                    break
                }
            }
            
            listener?.newConnectionHandler = { connection in
                print("New HTTP connection established")
                self.handleConnection(connection)
            }
            
            listener?.start(queue: .main)
        } catch {
            print("Failed to start HTTP Server: \(error)")
        }
    }
    
    private func handleConnection(_ connection: NWConnection) {
        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                print("Connection ready")
                self.receiveRequest(on: connection)
            case .failed(let error):
                print("Connection failed with error: \(error)")
            default:
                break
            }
        }
        connection.start(queue: .main)
    }
    
    private func receiveRequest(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 1024) { (data, _, isComplete, error) in
            if let data = data, let request = String(data: data, encoding: .utf8) {
                print("Received HTTP request:\n\(request)")
                
                // Generate a simple HTTP response
                let response = """
                HTTP/1.1 200 OK
                Content-Type: text/plain
                Content-Length: 13

                Hello, world!
                """
                
                connection.send(content: response.data(using: .utf8), completion: .contentProcessed { error in
                    if let error = error {
                        print("Failed to send response: \(error)")
                    } else {
                        print("Response sent successfully")
                    }
                    connection.cancel() // Close the connection after responding
                })
            }
            
            if error != nil || isComplete {
                connection.cancel() // Close the connection if an error occurs or if the request is complete
            } else {
                self.receiveRequest(on: connection) // Keep listening for requests
            }
        }
    }
    
    func stop() {
        listener?.cancel()
        listener = nil
    }
}
