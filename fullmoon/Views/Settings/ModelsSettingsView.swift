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
    @Environment(LLMEvaluator.self) var llm
    @State var showOnboardingInstallModelView = false
    
    var body: some View {
        Form {
            if appManager.selectedProvider == .anthropic {
                Section(header: Text("available models")) {
                    ForEach(AnthropicModel.availableModels) { model in
                        Button {
                            appManager.selectedAnthropicModelId = model.id
                            appManager.playHaptic()
                        } label: {
                            HStack {
                                Label {
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Text(model.name)
                                                .tint(.primary)
                                            if model.isLatest {
                                                Text("Latest")
                                                    .font(.caption)
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(Color.blue.opacity(0.2))
                                                    .foregroundColor(.blue)
                                                    .cornerRadius(4)
                                            }
                                        }
                                        Text(model.description)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                } icon: {
                                    Image(systemName: appManager.selectedAnthropicModelId == model.id ? "checkmark.circle.fill" : "circle")
                                }
                                Spacer()
                                Text("\(model.contextWindow / 1000)K")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        #if os(macOS)
                        .buttonStyle(.borderless)
                        #endif
                    }
                }
            } else {
                Section(header: Text("installed")) {
                    ForEach(appManager.installedModels, id: \.self) { modelName in
                        Button {
                            Task {
                                await switchModel(modelName)
                            }
                        } label: {
                            Label {
                                Text(appManager.modelDisplayName(modelName))
                                    .tint(.primary)
                            } icon: {
                                Image(systemName: appManager.currentModelName == modelName ? "checkmark.circle.fill" : "circle")
                            }
                        }
                        #if os(macOS)
                        .buttonStyle(.borderless)
                        #endif
                    }
                }
                
                Button {
                    showOnboardingInstallModelView.toggle()
                } label: {
                    Label("install a model", systemImage: "arrow.down.circle.dotted")
                }
                #if os(macOS)
                .buttonStyle(.borderless)
                #endif
            }
        }
        .formStyle(.grouped)
        .navigationTitle("models")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .sheet(isPresented: $showOnboardingInstallModelView) {
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
                                Text("close")
                            }
                        }
                        #endif
                    }
            }
        }
    }
    
    private func switchModel(_ modelName: String) async {
        if let model = ModelConfiguration.availableModels.first(where: {
            $0.name == modelName
        }) {
            appManager.currentModelName = modelName
            appManager.playHaptic()
            await llm.switchModel(model)
        }
    }
}

#Preview {
    ModelsSettingsView()
}
