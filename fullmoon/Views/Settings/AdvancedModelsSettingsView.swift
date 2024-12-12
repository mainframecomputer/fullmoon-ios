//
//  AdvancedModelsSettingsView.swift
//  fullmoon
//
//  Created by Jordan Singer on 12/11/24.
//

import SwiftUI
import Network

struct AdvancedModelsSettingsView: View {
    @EnvironmentObject var appManager: AppManager
    
    var body: some View {
        List {
            Section(header: Text("local network"), footer: Text("select a model from a device running fullmoon on your local network")) {
                Toggle(isOn: $appManager.shouldConnectToLocalNetwork) {
                    Text("connect")
                }
                .toggleStyle(.switch)
                .onChange(of: appManager.shouldConnectToLocalNetwork) { oldValue, newValue in
                    appManager.toggleLocalNetworking()
                }
                
                if appManager.shouldConnectToLocalNetwork {
                    if appManager.filteredDiscoveredPeers.isEmpty {
                        Text("searching...")
                            .foregroundStyle(.secondary)
                    }
                    
                    ForEach(appManager.filteredDiscoveredPeers, id: \.self) { endpoint in
                        Button {
                            appManager.connectToPeer(endpoint)
                            appManager.playHaptic()
                        } label: {
                            Label {
                                Text(getFriendlyName(from: endpoint))
                                    .lineLimit(1)
                                    .tint(.primary)
                            } icon: {
                                Image(systemName: appManager.isConnectedToPeer && appManager.connectedPeerName == getFriendlyName(from: endpoint) ? "checkmark.circle.fill" : "circle")
                            }
                        }
                        #if os(macOS)
                        .buttonStyle(.plain)
                        #endif
                    }
                }
            }

            if appManager.shouldConnectToLocalNetwork && !appManager.connectedClients.isEmpty {
                Section(header: Text("connected")) {
                    ForEach(appManager.connectedClients, id: \.self) { client in
                        Label {
                            Text(client)
                                .lineLimit(1)
                                .tint(.primary)
                        } icon: {
                            Image(systemName: "network")
                        }
                    }
                }
            }
        }
        .navigationTitle("advanced")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

#Preview {
    AdvancedModelsSettingsView()
}
