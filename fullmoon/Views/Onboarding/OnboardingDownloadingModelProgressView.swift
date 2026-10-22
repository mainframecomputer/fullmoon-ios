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
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedModel: ModelConfiguration
    @Environment(LLMEvaluator.self) var llm
    @State var didSwitchModel = false
    @State private var loadAttempt = UUID()
    
    var installed: Bool {
        llm.modelLoadStatus == .loaded && didSwitchModel
    }
    
    var body: some View {
        VStack {
            Spacer()
            
            VStack(spacing: 16) {
                if llm.modelLoadStatus.errorMessage == nil {
                    MoonAnimationView(isDone: installed)
                } else {
                    Image(.moon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 64, height: 64)
                        .opacity(0.6)
                }
                
                VStack(spacing: 4) {
                    Text(statusTitle)
                        .font(.title)
                        .fontWeight(.semibold)
                    Text(appManager.modelDisplayName(selectedModel.name))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                if let errorMessage = llm.modelLoadStatus.errorMessage {
                    VStack(spacing: 8) {
                        Text("your download is saved. continue when your connection is ready.")
                            .foregroundStyle(.secondary)
                        DisclosureGroup("details") {
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                } else {
                    ProgressView(value: llm.progress, total: 1)
                        .progressViewStyle(.linear)
                        .padding(.horizontal, 48)
                }
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
            } else if llm.modelLoadStatus.errorMessage != nil {
                VStack(spacing: 12) {
                    Button(action: retryLoad) {
                        Text("continue")
                            #if os(iOS) || os(visionOS)
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            #endif
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)

                    Button("choose another model") {
                        dismiss()
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
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
        .navigationTitle(llm.modelLoadStatus.errorMessage == nil ? "sit back and relax" : "model download")
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
        let succeeded = await llm.switchModel(selectedModel)
        guard succeeded else { return }

        didSwitchModel = true
        addInstalledModel()

        #if os(iOS)
        UIApplication.shared.isIdleTimerDisabled = false
        #endif
    }

    func retryLoad() {
        loadAttempt = UUID()
    }

    var statusTitle: String {
        if installed {
            return "installed"
        } else if llm.modelLoadStatus.errorMessage != nil {
            return "download paused"
        } else {
            return "installing"
        }
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
