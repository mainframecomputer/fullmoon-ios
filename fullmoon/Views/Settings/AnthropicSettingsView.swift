//
//  AnthropicSettingsView.swift
//  fullmoon
//
//  Created on 10/31/24.
//

import SwiftUI

struct AnthropicSettingsView: View {
    @EnvironmentObject var appManager: AppManager
    @State private var apiKey: String = ""
    @State private var showingAlert = false
    
    var body: some View {
        Form {
            Section(header: Text("api key")) {
                SecureField("Enter your Anthropic API key", text: $apiKey)
                    .textFieldStyle(.roundedBorder)
                    .onAppear {
                        apiKey = appManager.anthropicAPIKey
                    }
                
                Button("Save API Key") {
                    appManager.anthropicAPIKey = apiKey
                    showingAlert = true
                }
                .disabled(apiKey.isEmpty || apiKey == appManager.anthropicAPIKey)
                
                Text("You can get an API key from [console.anthropic.com](https://console.anthropic.com)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Section(header: Text("provider")) {
                Button {
                    appManager.selectedProvider = .local
                    appManager.anthropicAPIKey = ""
                    appManager.currentModelName = nil
                } label: {
                    Label("Switch to Local Models", systemImage: "internaldrive")
                        .foregroundColor(.red)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("api settings")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .alert("API Key Saved", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text("Your Anthropic API key has been saved.")
        }
    }
}

#Preview {
    NavigationStack {
        AnthropicSettingsView()
            .environmentObject(AppManager())
    }
}