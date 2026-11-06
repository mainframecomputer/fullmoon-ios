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
    #if !os(iOS)
    @State var showOnboardingInstallModelView = false
    #endif
    
    var body: some View {
        #if os(iOS)
        fixedModelSettings
        #else
        selectableModelSettings
        #endif
    }

    #if os(iOS)
    private var fixedModelSettings: some View {
        Form {
            Section {
                LabeledContent("model", value: appManager.modelDisplayName(llm.modelConfiguration.name))
                LabeledContent("status") {
                    Text(llm.modelStatus.title)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("modelStatus")
                }
                if case .downloading(let progress) = llm.modelStatus {
                    ProgressView(value: progress) {
                        Text("downloading")
                    } currentValueLabel: {
                        Text(progress, format: .percent.precision(.fractionLength(0)))
                    }
                }
                if case .loading = llm.modelStatus {
                    ProgressView("loading model")
                }
                if case .failed(let message) = llm.modelStatus {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
                if llm.modelStatus.canLoad {
                    Button(llm.modelStatus.actionTitle) {
                        Task {
                            do {
                                _ = try await llm.load(modelName: llm.modelConfiguration.name)
                                appManager.addInstalledModel(llm.modelConfiguration.name)
                            } catch {
                                // The evaluator publishes the load error above.
                            }
                        }
                    }
                }
            } footer: {
                Text("the model is fixed for this app")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("model")
        .navigationBarTitleDisplayMode(.inline)
        .task { llm.refreshModelStatus() }
    }
    #endif

    #if !os(iOS)
    private var selectableModelSettings: some View {
        Form {
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
                    .disabled(llm.isLoading)
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
            .disabled(llm.isLoading)
            #if os(macOS)
            .buttonStyle(.borderless)
            #endif
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
    #endif
}

#Preview {
    ModelsSettingsView()
        .environmentObject(AppManager())
        .environment(LLMEvaluator())
}
