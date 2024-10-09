//
//  OnboardingDownloadingModelProgressView.swift
//  fullmoon
//
//  Created by Jordan Singer on 10/4/24.
//

import SwiftUI
import MLXLLM

struct OnboardingDownloadingModelProgressView: View {
    @Binding var showOnboarding: Bool
    @EnvironmentObject var appManager: AppManager
    @Binding var selectedModel: ModelConfiguration
    @EnvironmentObject var llm: LLMEvaluator
    @State var installed = false
    
    let moonPhases = [
        "moonphase.new.moon",
        "moonphase.waning.crescent",
        "moonphase.last.quarter",
        "moonphase.waning.gibbous",
        "moonphase.full.moon",
        "moonphase.waxing.gibbous",
        "moonphase.first.quarter",
        "moonphase.waxing.crescent",
    ]
    @State var currentPhaseIndex = 0
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack {
            Spacer()
            
            VStack(spacing: 16) {
                Image(systemName: isInstalled() ? "checkmark.circle.fill" : moonPhases[currentPhaseIndex])
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 64, height: 64)
                    .foregroundStyle(isInstalled() ? .green : .secondary)
                    .onReceive(timer) { time in
                        currentPhaseIndex = (currentPhaseIndex + 1) % moonPhases.count
                    }
                
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
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .foregroundStyle(.background)
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
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .task {
            await loadLLM()
        }
        .sensoryFeedback(.success, trigger: isInstalled())
        .onChange(of: llm.progress) { _ in
            addInstalledModel()
        }
        .interactiveDismissDisabled(!isInstalled())
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
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
}
