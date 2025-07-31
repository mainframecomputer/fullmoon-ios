//
//  OnboardingProviderSelectionView.swift
//  fullmoon
//
//  Created on 10/31/24.
//

import SwiftUI

struct OnboardingProviderSelectionView: View {
    @Binding var showOnboarding: Bool
    @State private var selectedProvider: ModelProvider = .local
    @State private var anthropicAPIKey: String = ""
    @EnvironmentObject var appManager: AppManager
    
    var body: some View {
        Form {
            Section {
                VStack(spacing: 12) {
                    Image(systemName: "cpu")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 64, height: 64)
                        .foregroundStyle(.primary, .tertiary)
                    
                    VStack(spacing: 4) {
                        Text("choose your model")
                            .font(.title)
                            .fontWeight(.semibold)
                        Text("select how you want to run your language model")
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.vertical)
                .frame(maxWidth: .infinity)
            }
            .listRowBackground(Color.clear)
            
            Section(header: Text("provider")) {
                ForEach(ModelProvider.allCases, id: \.self) { provider in
                    Button {
                        selectedProvider = provider
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(provider.rawValue)
                                    .tint(.primary)
                                Text(provider.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: selectedProvider == provider ? "checkmark.circle.fill" : "circle")
                        }
                    }
                    #if os(macOS)
                    .buttonStyle(.borderless)
                    #endif
                }
            }
            
            if selectedProvider == .anthropic {
                Section(header: Text("api key")) {
                    SecureField("Enter your Anthropic API key", text: $anthropicAPIKey)
                        .textFieldStyle(.roundedBorder)
                    
                    Text("You can get an API key from [console.anthropic.com](https://console.anthropic.com)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            #if os(macOS)
            Section {} footer: {
                NavigationLink(destination: destinationView()) {
                    Text("continue")
                        .buttonStyle(.borderedProminent)
                }
                .disabled(selectedProvider == .anthropic && anthropicAPIKey.isEmpty)
            }
            .padding()
            #endif
        }
        .formStyle(.grouped)
        #if os(iOS) || os(visionOS)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(destination: destinationView()) {
                    Text("continue")
                        .font(.headline)
                }
                .disabled(selectedProvider == .anthropic && anthropicAPIKey.isEmpty)
            }
        }
        .listStyle(.insetGrouped)
        #endif
    }
    
    @ViewBuilder
    func destinationView() -> some View {
        if selectedProvider == .local {
            OnboardingInstallModelView(showOnboarding: $showOnboarding)
        } else {
            OnboardingCompleteView(showOnboarding: $showOnboarding, selectedProvider: selectedProvider, anthropicAPIKey: anthropicAPIKey)
        }
    }
}

#Preview {
    OnboardingProviderSelectionView(showOnboarding: .constant(true))
        .environmentObject(AppManager())
}
