//
//  ModelsSettingsView.swift
//  fullmoon
//
//  Created by Jordan Singer on 10/5/24.
//

import SwiftUI
import MLXLMCommon

struct ModelsSettingsView: View {
    @EnvironmentObject var appManager: AppManager
    @Environment(LLMEvaluator.self) private var llm
    @State private var showOnboardingInstallModelView = false
    @State private var isInitialLoad = true
    @State private var showingAddServer = false
    @State private var serverURL = ""
    @State private var serverAPIKey = ""
    @State private var serverType: ServerConfig.ServerType = .openai
    @State private var isLoadingModels = false
    
    var body: some View {
        Form {
            serverSection
            
            if appManager.isUsingServer {
                serverModelsSection
            } else {
                localModelsSection
            }
            
            Section("Server Configuration") {
                if !appManager.servers.isEmpty {
                    Picker("Selected Server", selection: $appManager.selectedServerId) {
                        Text("None").tag(Optional<UUID>.none)
                        ForEach(appManager.servers) { server in
                            Text(server.url).tag(Optional(server.id))
                        }
                    }
                    
                    if let selectedServer = appManager.currentServer {
                        SecureField("API Key", text: Binding(
                            get: { selectedServer.apiKey },
                            set: { newValue in
                                if let index = appManager.servers.firstIndex(where: { $0.id == selectedServer.id }) {
                                    appManager.servers[index].apiKey = newValue
                                    appManager.saveServers()
                                }
                            }
                        ))
                        .textFieldStyle(.roundedBorder)
                        
                        Button("Remove Server") {
                            appManager.removeServer(selectedServer)
                        }
                        .foregroundColor(.red)
                    }
                }
                
                Button("Add Server") {
                    showingAddServer = true
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("models")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .sheet(isPresented: $showOnboardingInstallModelView) {
            modelInstallSheet
        }
        .sheet(isPresented: $showingAddServer) {
            NavigationStack {
                Form {
                    Section {
                        TextField("Server URL", text: $serverURL)
                        SecureField("API Key", text: $serverAPIKey)
                        Picker("Server Type", selection: $serverType) {
                            ForEach(ServerConfig.ServerType.allCases, id: \.self) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                    }
                }
                .navigationTitle("Add Server")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            showingAddServer = false
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Add") {
                            let server = ServerConfig(url: serverURL, apiKey: serverAPIKey, type: serverType)
                            appManager.addServer(server)
                            showingAddServer = false
                            serverURL = ""
                            serverAPIKey = ""
                        }
                        .disabled(serverURL.isEmpty)
                    }
                }
            }
            .presentationDetents([.medium])
        }
        // Load models when server changes
        .onChange(of: appManager.selectedServerId) { _ in
            Task {
                await loadModels()
            }
        }
        // Load models when server mode changes
        .onChange(of: appManager.isUsingServer) { isServer in
            if isServer {
                Task {
                    await loadModels()
                }
            }
        }
        // Initial load
        .task {
            if isInitialLoad && appManager.isUsingServer {
                isInitialLoad = false
                await loadModels()
            }
        }
    }
    
    private func loadModels() async {
        guard let server = appManager.currentServer else { return }
        
        await MainActor.run {
            llm.isLoadingModels = true
            // Clear current models while loading
            llm.serverModels = []
        }
        
        // First show cached models
        await MainActor.run {
            llm.serverModels = appManager.getCachedModels(for: server.id)
        }
        
        // Then fetch fresh models
        let models = await llm.fetchServerModels(for: server)
        
        await MainActor.run {
            llm.serverModels = models
            appManager.updateCachedModels(serverId: server.id, models: models)
            llm.isLoadingModels = false
        }
    }
    
    // MARK: - View Components
    
    private var serverSection: some View {
        Section {
            Toggle("Use Server API", isOn: $appManager.isUsingServer)
                .toggleStyle(.switch)
            
            if appManager.isUsingServer {
                ForEach(appManager.servers) { server in
                    HStack {
                        Button {
                            appManager.selectedServerId = server.id
                        } label: {
                            HStack {
                                Text(server.name)
                                    .foregroundStyle(appManager.selectedServerId == server.id ? .primary : .secondary)
                                Spacer()
                                if appManager.selectedServerId == server.id {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        
                        Spacer()
                        
                        Button {
                            appManager.removeServer(server)
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        } footer: {
            Text("Configure to use local models or connect to a server that supports OpenAI API spec")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
    
    private var serverModelsSection: some View {
        Section {
            if llm.isLoadingModels {
                HStack {
                    Spacer()
                    ProgressView()
                        .controlSize(.small)
                    Spacer()
                }
            } else if llm.serverModels.isEmpty {
                Text("No models available")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            } else {
                ForEach(llm.serverModels, id: \.self) { model in
                    Button {
                        appManager.currentModelName = model
                    } label: {
                        HStack {
                            Text(model)
                                .foregroundStyle(appManager.currentModelName == model ? .primary : .secondary)
                            Spacer()
                            if appManager.currentModelName == model {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        } header: {
            HStack {
                Text("Available Server Models")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    Task {
                        await loadModels()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .foregroundStyle(.secondary)
                        .font(.footnote)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private var localModelsSection: some View {
        Section {
            ForEach(appManager.installedModels, id: \.self) { modelName in
                modelButton(modelName: modelName, isServer: false)
            }
            
            Button {
                showOnboardingInstallModelView.toggle()
            } label: {
                Label {
                    Text("Install New Model")
                        .foregroundStyle(.secondary)
                } icon: {
                    Image(systemName: "arrow.down.circle")
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
        } header: {
            Text("Installed Models")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
    
    private func modelButton(modelName: String, isServer: Bool) -> some View {
        Button {
            Task {
                if isServer {
                    appManager.isUsingServer = true
                    appManager.currentModelName = modelName
                    appManager.playHaptic()
                } else {
                    appManager.isUsingServer = false
                    appManager.currentModelName = modelName
                    appManager.playHaptic()
                }
            }
        } label: {
            HStack {
                Text(modelName)
                    .foregroundStyle(appManager.currentModelName == modelName ? .primary : .secondary)
                Spacer()
                if appManager.currentModelName == modelName {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
    }
    
    private var modelInstallSheet: some View {
        NavigationStack {
            OnboardingInstallModelView(showOnboarding: $showOnboardingInstallModelView)
                .environment(llm)
                .toolbar {
                    #if os(iOS) || os(visionOS)
                    ToolbarItem(placement: .topBarLeading) {
                        Button(action: { showOnboardingInstallModelView = false }) {
                            Image(systemName: "xmark")
                        }
                    }
                    #elseif os(macOS)
                    ToolbarItem(placement: .destructiveAction) {
                        Button(action: { showOnboardingInstallModelView = false }) {
                            Text("Close")
                        }
                    }
                    #endif
                }
        }
    }
}

#Preview {
    NavigationStack {
        ModelsSettingsView()
            .environmentObject(AppManager())
            .environment(LLMEvaluator(appManager: AppManager()))
    }
}
