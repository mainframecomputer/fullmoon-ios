//
//  OnboardingInstallModelView.swift
//  fullmoon
//
//  Created by Jordan Singer on 10/4/24.
//

import SwiftUI
import MLXLLM

struct OnboardingInstallModelView: View {
    @EnvironmentObject var appManager: AppManager
    @Binding var showOnboarding: Bool
    @State var selectedModel = ModelConfiguration.defaultModel
    let suggestedModel = ModelConfiguration.defaultModel
    
    var body: some View {
        List {
            Section {
                VStack(spacing: 12) {
                    Image(systemName: "arrow.down.circle.dotted")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 64, height: 64)
                        .foregroundStyle(.primary, .tertiary)
                    
                    VStack(spacing: 4) {
                        Text("install a model")
                            .font(.title)
                            .fontWeight(.semibold)
                        Text("select from models that are optimized for apple silicon")
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.vertical)
                .frame(maxWidth: .infinity)
            }
            .listRowBackground(Color.clear)
            
            if appManager.installedModels.count > 0 {
                Section(header: Text("Installed")) {
                    ForEach(appManager.installedModels, id: \.self) { modelName in
                        Button { } label: {
                            Label {
                                Text(appManager.modelDisplayName(modelName))
                            } icon: {
                                Image(systemName: "checkmark")
                            }
                        }
                        .foregroundStyle(.secondary)
                        .disabled(true)
                    }
                }
            } else {
                Section(header: Text("Suggested")) {
                    Button { selectedModel = suggestedModel } label: {
                        Label {
                            Text(appManager.modelDisplayName(suggestedModel.name))
                                .tint(.primary)
                        } icon: {
                            Image(systemName: selectedModel.name == suggestedModel.name ? "checkmark.circle.fill" : "circle")
                        }
                    }
                }
            }
            
            if filteredModels.count > 0 {
                Section(header: Text("Other")) {
                    ForEach(filteredModels, id: \.name) { model in
                        Button { selectedModel = model } label: {
                            Label {
                                Text(appManager.modelDisplayName(model.name))
                                    .tint(.primary)
                            } icon: {
                                Image(systemName: selectedModel.name == model.name ? "checkmark.circle.fill" : "circle")
                            }
                        }
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(destination: OnboardingDownloadingModelProgressView(showOnboarding: $showOnboarding, selectedModel: $selectedModel)) {
                    Text("install")
                        .font(.headline)
                }
                .disabled(filteredModels.isEmpty)
            }
        }
        .listStyle(.insetGrouped)
        .task {
            checkModels()
        }
    }
    
    var filteredModels: [ModelConfiguration] {
        ModelConfiguration.availableModels
            .filter { !appManager.installedModels.contains($0.name) }
            .filter { model in
                !(appManager.installedModels.isEmpty && model.name == suggestedModel.name)
            }
            .sorted { $0.name < $1.name }
    }
    
    func checkModels() {
        // automatically select the first available model
        if appManager.installedModels.contains(suggestedModel.name) {
            if let model = filteredModels.first {
                selectedModel = model
            }
        }
    }
}

#Preview {
    OnboardingInstallModelView(showOnboarding: .constant(true))
}
