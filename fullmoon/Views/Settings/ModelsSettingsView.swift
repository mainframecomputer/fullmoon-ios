//
//  ModelsSettingsView.swift
//  fullmoon
//
//  Created by Jordan Singer on 10/5/24.
//

import SwiftUI
import MLXLLM

struct ModelsSettingsView: View {
    @EnvironmentObject var appManager: AppManager
    @EnvironmentObject var llm: LLMEvaluator
    @State var showOnboardingInstallModelView = false
    
    var body: some View {
        List {
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
                }
            }
            
            Button {
                showOnboardingInstallModelView.toggle()
            } label: {
                Label("install a model", systemImage: "arrow.down.circle.dotted")
            }
        }
        .navigationTitle("models")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showOnboardingInstallModelView) {
            NavigationStack {
                OnboardingInstallModelView(showOnboarding: $showOnboardingInstallModelView)
                    .environment(llm)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button(action: { showOnboardingInstallModelView = false }) {
                                Image(systemName: "xmark")
                            }
                        }
                    }
            }
        }
    }
    
    private func switchModel(_ modelName: String) async {
        if let model = ModelConfiguration.availableModels.first(where: {
            $0.name == modelName
        }) {
            appManager.currentModelName = modelName
            let impact = UIImpactFeedbackGenerator(style: .soft)
            impact.impactOccurred()
            await llm.switchModel(model)
        }
    }
}

#Preview {
    ModelsSettingsView()
}
