//
//  SettingsView.swift
//  fullmoon
//
//  Created by Jordan Singer on 10/4/24.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appManager: AppManager
    @Environment(\.dismiss) var dismiss
    @Environment(LLMEvaluator.self) var llm
    @Binding var currentThread: Thread?
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink(destination: AppearanceSettingsView()) {
                        Label("appearance", systemImage: "paintpalette")
                    }
                    
                    NavigationLink(destination: ChatsSettingsView(currentThread: $currentThread)) {
                        Label("chats", systemImage: "message")
                    }
                    
                    NavigationLink(destination: ModelsSettingsView()) {
                        Label("models", systemImage: "arrow.down.circle")
                            .badge(appManager.modelDisplayName(appManager.currentModelName ?? ""))
                    }
                }
                
                Section {
                    NavigationLink(destination: CreditsView()) {
                        Text("credits")
                    }
                }
                
                Section {
                    HStack {
                        Spacer()
                        Image(systemName: appManager.getMoonPhaseIcon())
                            .foregroundStyle(.quaternary)
                        Spacer()
                    }
                    .padding(.vertical)
                }
                .listRowBackground(Color.clear)
            }
            .navigationTitle("settings")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                    }
                }
                #elseif os(macOS)
                ToolbarItem(placement: .destructiveAction) {
                    Button(action: { dismiss() }) {
                        Text("close")
                    }
                }
                #endif
            }
        }
        .tint(appManager.appTintColor.getColor())
        .environment(\.dynamicTypeSize, appManager.appFontSize.getFontSize())
        #if os(macOS)
        .frame(width: 320, height: 320)
        #endif
    }
}

#Preview {
    SettingsView(currentThread: .constant(nil))
}
