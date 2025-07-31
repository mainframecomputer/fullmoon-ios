//
//  OnboardingCompleteView.swift
//  fullmoon
//
//  Created on 10/31/24.
//

import SwiftUI

struct OnboardingCompleteView: View {
    @Binding var showOnboarding: Bool
    let selectedProvider: ModelProvider
    let anthropicAPIKey: String
    @EnvironmentObject var appManager: AppManager
    
    var body: some View {
        VStack {
            Spacer()
            
            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 64, height: 64)
                    .foregroundStyle(.green)
                
                VStack(spacing: 4) {
                    Text("all set!")
                        .font(.title)
                        .fontWeight(.semibold)
                    Text("You're ready to start using Claude 4 Opus")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            
            Spacer()
            
            Button {
                // Save the API key and provider selection
                appManager.selectedProvider = selectedProvider
                appManager.anthropicAPIKey = anthropicAPIKey
                appManager.currentModelName = "claude-opus-4"
                showOnboarding = false
            } label: {
                Text("get started")
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
        }
        .padding()
        .navigationTitle("setup complete")
        #if os(macOS)
        .frame(width: 420, height: 520)
        #endif
    }
}

#Preview {
    OnboardingCompleteView(showOnboarding: .constant(true), selectedProvider: .anthropic, anthropicAPIKey: "test-key")
        .environmentObject(AppManager())
}
