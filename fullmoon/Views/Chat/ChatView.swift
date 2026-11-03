//
//  ChatView.swift
//  fullmoon
//
//  Created by Jordan Singer on 12/3/24.
//

import SwiftUI

struct ChatView: View {
    @EnvironmentObject var appManager: AppManager
    @Binding var currentThread: Thread?
    @State var prompt = ""
    @FocusState.Binding var isPromptFocused: Bool
    @Binding var showChats: Bool
    @Binding var showSettings: Bool
    
    let platformBackgroundColor: Color = {
        #if os(iOS)
        return Color(UIColor.secondarySystemBackground)
        #elseif os(visionOS)
        return Color(UIColor.separator)
        #elseif os(macOS)
        return Color(NSColor.secondarySystemFill)
        #endif
    }()

    var chatInput: some View {
        HStack(alignment: .bottom, spacing: 0) {
            TextField("message", text: $prompt, axis: .vertical)
                .focused($isPromptFocused)
                .textFieldStyle(.plain)
            #if os(iOS) || os(visionOS)
                .padding(.horizontal, 16)
            #elseif os(macOS)
                .padding(.horizontal, 12)
            #endif
                .padding(.vertical, 8)
            #if os(iOS) || os(visionOS)
                .frame(minHeight: 48)
            #elseif os(macOS)
                .frame(minHeight: 32)
            #endif
        }
        .disabled(true)
        .help("Noctis n’est pas encore connecté.")
        #if os(iOS) || os(visionOS)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(platformBackgroundColor)
        )
        #elseif os(macOS)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(platformBackgroundColor)
        )
        #endif
    }

    var chatTitle: String {
        if let currentThread = currentThread {
            if let firstMessage = currentThread.sortedMessages.first {
                return firstMessage.content
            }
        }

        return "chat"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let currentThread = currentThread {
                    ConversationView(thread: currentThread)
                } else {
                    Spacer()
                    Image(systemName: appManager.getMoonPhaseIcon())
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 32, height: 32)
                        .foregroundStyle(.quaternary)
                    Spacer()
                }

                Text("Noctis n’est pas encore connecté.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                chatInput
                    .padding()
            }
            .navigationTitle(chatTitle)
            #if os(iOS) || os(visionOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
                .toolbar {
                    #if os(iOS) || os(visionOS)
                    if appManager.userInterfaceIdiom == .phone {
                        ToolbarItem(placement: .topBarLeading) {
                            Button(action: {
                                appManager.playHaptic()
                                showChats.toggle()
                            }) {
                                Image(systemName: "list.bullet")
                            }
                        }
                    }

                    ToolbarItem(placement: .topBarTrailing) {
                        Button(action: {
                            appManager.playHaptic()
                            showSettings.toggle()
                        }) {
                            Image(systemName: "gear")
                        }
                    }
                    #elseif os(macOS)
                    ToolbarItem(placement: .primaryAction) {
                        Button(action: {
                            appManager.playHaptic()
                            showSettings.toggle()
                        }) {
                            Label("settings", systemImage: "gear")
                        }
                    }
                    #endif
                }
        }
    }

}

#Preview {
    @FocusState var isPromptFocused: Bool
    ChatView(currentThread: .constant(nil), isPromptFocused: $isPromptFocused, showChats: .constant(false), showSettings: .constant(false))
}
