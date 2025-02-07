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
    @State private var resetAnimation = false
    
    var installed: Bool {
        llm.progress == 1 && didSwitchModel
    }
    
    var body: some View {
        VStack {
            Spacer()
            
            VStack(spacing: 16) {
                MoonAnimationView(isDone: installed, resetAnimation: resetAnimation)
                
                VStack(spacing: 4) {
                    Text(installed ? "installed" : "installing")
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
            } else {
                if llm.progress >= 0.80 && !llm.isModelFullyLoaded {
                    Text("please keep app open to complete download")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                } else {
                    Text("you can leave the app while downloading")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
        }
        .padding()
        .navigationTitle("downloading model")
        .toolbar(installed ? .hidden : .visible)
        .navigationBarBackButtonHidden()
        .task {
            // Prevent device from sleeping during download
            UIApplication.shared.isIdleTimerDisabled = true
            
            // Request notification permissions
            try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
            
            // Wait until the app is in the foreground
            while UIApplication.shared.applicationState != .active {
                await withCheckedContinuation { continuation in
                    var token: NSObjectProtocol?
                    token = NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { _ in
                        if let token = token {
                            NotificationCenter.default.removeObserver(token)
                        }
                        continuation.resume()
                    }
                }
                // Brief delay after activation
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
            
            // Check for an interrupted download and resume it automatically
            if let (modelName, progress) = appManager.loadInterruptedDownload() {
                selectedModel = ModelConfiguration.getModelByName(modelName) ?? selectedModel
                llm.progress = progress
                print("OnboardingDownloadingModelProgressView: Resuming interrupted download for model: \(modelName) at progress \(progress)")
            }
            
            // Now safe to load the model
            await loadLLM()
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            appManager.clearInterruptedDownload()
        }
        #if os(iOS)
        .sensoryFeedback(.success, trigger: installed)
        #endif
        .onChange(of: installed) {
            addInstalledModel()
        }
        .interactiveDismissDisabled(!installed)
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            resetAnimation.toggle()
        }
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
        didSwitchModel = true
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
