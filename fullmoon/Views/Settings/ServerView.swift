//
//  ServerView.swift
//  fullmoon
//
//  Created by Jordan Singer on 12/15/24.
//

import SwiftUI

struct ServerView: View {
    @StateObject private var server = HTTPServer()
    @State private var isServerRunning = false
    
    var body: some View {
        List {
            if isServerRunning {
                Text("HTTP Server is running")
                    .foregroundColor(.green)
            } else {
                Text("HTTP Server is stopped")
                    .foregroundColor(.red)
            }
            
            Button(isServerRunning ? "Stop Server" : "Start Server") {
                if isServerRunning {
                    server.stop()
                    isServerRunning = false
                } else {
                    server.start(port: 8080)
                    isServerRunning = true
                }
            }
        }
        .navigationTitle("server")
    }
}

#Preview {
    ServerView()
}
