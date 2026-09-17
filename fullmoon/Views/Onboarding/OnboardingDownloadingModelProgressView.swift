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
    @State var didSwitchModel = false
    @State private var loadAttempt = UUID()
    
    var installed: Bool {
        llm.modelLoadStatus == .loaded && didSwitchModel
    }

    var failed: Bool {
        if case .failed = llm.modelLoadStatus {
            return true
        }
        return false
    }
    
    var body: some View {
        VStack {
            Spacer()
            
            VStack(spacing: 16) {
                MoonAnimationView(isDone: installed)
                
                VStack(spacing: 4) {
                    Text(installed ? "installed" : failed ? "download failed" : "installing")
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
            
            if installed {
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
            } else if failed {
                VStack(spacing: 12) {
                    Text("The model could not be downloaded. Check your connection and try again.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    Button("try again") {
                        didSwitchModel = false
                        loadAttempt = UUID()
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                }
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
        .toolbar(installed ? .hidden : .visible)
        .task(id: loadAttempt) {
            await loadLLM()
        }
        #if os(iOS)
        .sensoryFeedback(.success, trigger: installed)
        #endif
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
        guard await llm.switchModel(selectedModel) else {
            didSwitchModel = false
            return
        }

        didSwitchModel = true
        #if os(iOS)
        UIApplication.shared.isIdleTimerDisabled = false
        #endif
        addInstalledModel()
    }
    
    func addInstalledModel() {
        if installed {
            print("added installed model")
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
