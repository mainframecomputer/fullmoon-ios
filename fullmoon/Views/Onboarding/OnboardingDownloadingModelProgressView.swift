//
//  OnboardingDownloadingModelProgressView.swift
//  fullmoon
//
//  Created by Jordan Singer on 10/4/24.
//

import SwiftUI
import MLXLMCommon

struct OnboardingDownloadingModelProgressView: View {
    @Binding var showOnboarding: Bool
    @EnvironmentObject var appManager: AppManager
    @Binding var selectedModel: ModelConfiguration
    @Environment(LLMEvaluator.self) var llm
    @State var installed = false
    
    var body: some View {
        VStack {
            Spacer()
            
            VStack(spacing: 16) {
                MoonAnimationView(isDone: isInstalled())
                
                VStack(spacing: 4) {
                    Text(isInstalled() ? "installed" : "installing")
                        .font(.title)
                        .fontWeight(.semibold)
                    Text(appManager.modelDisplayName(selectedModel.name))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                ProgressView(value: llm.progress, total: 1)
                    .progressViewStyle(.linear)
                    .padding(.horizontal, 48)
            }
            
            Spacer()
            
            if isInstalled() {
                Button(action: { showOnboarding = false }) {
                    Text("done")
                        #if os(iOS) || os(visionOS)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        #endif
                        #if os(iOS)
                        .foregroundStyle(.background)
                        #endif
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .padding(.horizontal)
            } else {
                Text("keep this screen open and wait for the installation to complete.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .padding()
        .navigationTitle("sit back and relax")
        .toolbar(isInstalled() ? .hidden : .visible)
        .navigationBarBackButtonHidden()
        .task {
            await loadLLM()
        }
        #if os(iOS)
        .sensoryFeedback(.success, trigger: isInstalled())
        #endif
        .onChange(of: llm.progress) {
            addInstalledModel()
        }
        .interactiveDismissDisabled(!isInstalled())
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
        #endif
    }
    
    func loadLLM() async {
        await llm.switchModel(selectedModel)
    }
    
    func isInstalled() -> Bool {
        if llm.progress == 1 {
            installed = true
        }
        
        return installed && llm.progress == 1
    }
    
    func addInstalledModel() {
        if isInstalled() {
            appManager.currentModelName = selectedModel.name
            appManager.addInstalledModel(selectedModel.name)
        }
    }
}

#Preview {
    OnboardingDownloadingModelProgressView(showOnboarding: .constant(true), selectedModel: .constant(ModelConfiguration.defaultModel))
        .environmentObject(AppManager())
        .environment(LLMEvaluator())
}
