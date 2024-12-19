//
//  OnboardingInstallModelView.swift
//  fullmoon
//
//  Created by Jordan Singer on 10/4/24.
//

import MLXLMCommon
import SwiftUI

struct OnboardingInstallModelView: View {
    @EnvironmentObject var appManager: AppManager
    @State private var deviceSupportsMetal3: Bool = true
    @Binding var showOnboarding: Bool
    @State var selectedModel = ModelConfiguration.defaultModel
    let suggestedModel = ModelConfiguration.defaultModel

    func sizeBadge(_ model: ModelConfiguration?) -> String? {
        guard let size = model?.modelSize else { return nil }
        return "\(size) GB"
    }

    var modelsList: some View {
        Form {
            Section {
                VStack(spacing: 12) {
                    Image(systemName: "arrow.down.circle.dotted")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 64, height: 64)
                        .foregroundStyle(.primary, .tertiary)

                    VStack(spacing: 4) {
                        Text("install a model")
                            .font(.title)
                            .fontWeight(.semibold)
                        Text("select from models that are optimized for apple silicon")
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.vertical)
                .frame(maxWidth: .infinity)
            }
            .listRowBackground(Color.clear)

            if appManager.installedModels.count > 0 {
                Section(header: Text("installed")) {
                    ForEach(appManager.installedModels, id: \.self) { modelName in
                        let model = ModelConfiguration.getModelByName(modelName)
                        Button {} label: {
                            Label {
                                Text(appManager.modelDisplayName(modelName))
                            } icon: {
                                Image(systemName: "checkmark")
                            }
                        }
                        .badge(sizeBadge(model))
                        #if os(macOS)
                            .buttonStyle(.borderless)
                        #endif
                            .foregroundStyle(.secondary)
                            .disabled(true)
                    }
                }
            } else {
                Section(header: Text("suggested")) {
                    Button { selectedModel = suggestedModel } label: {
                        Label {
                            Text(appManager.modelDisplayName(suggestedModel.name))
                                .tint(.primary)
                        } icon: {
                            Image(systemName: selectedModel.name == suggestedModel.name ? "checkmark.circle.fill" : "circle")
                        }
                    }
                    .badge(sizeBadge(suggestedModel))
                    #if os(macOS)
                        .buttonStyle(.borderless)
                    #endif
                }
            }

            if filteredModels.count > 0 {
                Section(header: Text("other")) {
                    ForEach(filteredModels, id: \.name) { model in
                        Button { selectedModel = model } label: {
                            Label {
                                Text(appManager.modelDisplayName(model.name))
                                    .tint(.primary)
                            } icon: {
                                Image(systemName: selectedModel.name == model.name ? "checkmark.circle.fill" : "circle")
                            }
                        }
                        .badge(sizeBadge(model))
                        #if os(macOS)
                            .buttonStyle(.borderless)
                        #endif
                    }
                }
            }

            #if os(macOS)
            Section {} footer: {
                NavigationLink(destination: OnboardingDownloadingModelProgressView(showOnboarding: $showOnboarding, selectedModel: $selectedModel)) {
                    Text("install")
                        .buttonStyle(.borderedProminent)
                }
                .disabled(filteredModels.isEmpty)
            }
            .padding()
            #endif
        }
        .formStyle(.grouped)
    }

    var body: some View {
        ZStack {
            if deviceSupportsMetal3 {
                modelsList
                #if os(iOS) || os(visionOS)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        NavigationLink(destination: OnboardingDownloadingModelProgressView(showOnboarding: $showOnboarding, selectedModel: $selectedModel)) {
                            Text("install")
                                .font(.headline)
                        }
                        .disabled(filteredModels.isEmpty)
                    }
                }
                .listStyle(.insetGrouped)
                #endif
                .task {
                    checkModels()
                }
            } else {
                DeviceNotSupportedView()
            }
        }
        .onAppear {
            checkMetal3Support()
        }
    }

    var filteredModels: [ModelConfiguration] {
        ModelConfiguration.availableModels
            .filter { !appManager.installedModels.contains($0.name) }
            .filter { model in
                !(appManager.installedModels.isEmpty && model.name == suggestedModel.name)
            }
            .sorted { $0.name < $1.name }
    }

    func checkModels() {
        // automatically select the first available model
        if appManager.installedModels.contains(suggestedModel.name) {
            if let model = filteredModels.first {
                selectedModel = model
            }
        }
    }

    func checkMetal3Support() {
        #if os(iOS)
        if let device = MTLCreateSystemDefaultDevice() {
            deviceSupportsMetal3 = device.supportsFamily(.metal3)
        }
        #endif
    }
}

#Preview {
    @Previewable @State var appManager = AppManager()

    OnboardingInstallModelView(showOnboarding: .constant(true))
        .environmentObject(appManager)
}
