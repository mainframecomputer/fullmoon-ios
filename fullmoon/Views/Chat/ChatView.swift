//
//  ChatView.swift
//  Noctis
//

import SwiftUI
import SwiftData

struct ChatView: View {
    @Environment(AppManager.self) private var appManager
    @Environment(\.modelContext) private var modelContext
    @Binding var currentThread: Thread?
    @FocusState.Binding var isPromptFocused: Bool

    @Binding var showChats: Bool
    @Binding var showSettings: Bool

    let viewModel: ViewModel


    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                conversationContent

                connectionStatus

                Composer(
                    viewModel: viewModel,
                    isPromptFocused: $isPromptFocused,
                    onSend: {
                        viewModel.send(to: currentThread, in: modelContext) { currentThread = $0 }
                    }
                )
                .frame(maxWidth: appManager.appearance.contentWidth)
                .padding(DesignTokens.pageInset)
            }
            .background(appManager.appearance.theme.background)
            .navigationTitle(
                viewModel.chatTitle(for: currentThread)
            )
#if os(iOS) || os(visionOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                chatToolbar
            }
        }
        .onDisappear { viewModel.stop() }
        .onChange(of: currentThread?.id) {
            if let generatingID = viewModel.generatingMessageID,
               currentThread?.messages.contains(where: { $0.id == generatingID }) != true {
                viewModel.stop()
            }
        }
        .task {
            guard ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" else {
                return
            }

            await viewModel.loadModel()
        }
    }

    // Observe draft changes here so typing does not invalidate the conversation or title.
    private struct Composer: View {
        @Bindable var viewModel: ViewModel
        @FocusState.Binding var isPromptFocused: Bool
        let onSend: () -> Void

        var body: some View {
            VStack(spacing: 8) {
                if let error = viewModel.submissionError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.primary)
                        .accessibilityLabel("Message could not be sent: \(error)")
                }

                ChatInputView(
                    prompt: $viewModel.prompt,
                    isPromptFocused: $isPromptFocused,
                    isEnabled: viewModel.isInputEnabled,
                    canSend: viewModel.hasMeaningfulPrompt,
                    isLoading: viewModel.isLoading,
                    isSending: viewModel.isSending,
                    isStopping: viewModel.isStopping,
                    onStop: { viewModel.stop() }
                ) {
                    onSend()
                }
            }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var conversationContent: some View {
        if let currentThread {
            ConversationView(thread: currentThread, onRegenerate: { message in
                viewModel.regenerate(message, in: currentThread, context: modelContext) { self.currentThread = $0 }
            }, generatingMessageID: viewModel.generatingMessageID)
        } else {
            emptyConversation
        }
    }

    private var emptyConversation: some View {
        WelcomeConversation { suggestion in
            viewModel.prompt = suggestion
            isPromptFocused = true
        }
    }

    // MARK: - Connection Status
    @ViewBuilder
    private var connectionStatus: some View {
        if !viewModel.isConnected {
            Text(viewModel.connectionMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
            if !viewModel.isLoading && viewModel.submissionError != nil {
                Button("Réessayer") {
                    Task { await viewModel.loadModel() }
                }
            }
        } else if !viewModel.isSending {
            Label("Modèle local · Prêt", systemImage: "checkmark.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Toolbar
    @ToolbarContentBuilder
    private var chatToolbar: some ToolbarContent {

#if os(iOS) || os(visionOS)

        if appManager.userInterfaceIdiom == .phone {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    appManager.playHaptic()
                    showChats.toggle()
                } label: {
                    Image(systemName: "list.bullet")
                }
            }
        }

        ToolbarItem(placement: .topBarTrailing) {
            settingsButton
        }

#elseif os(macOS)

        ToolbarItem(placement: .primaryAction) {
            settingsButton
        }

#endif
    }

    // MARK: - Actions
    private var settingsButton: some View {
        Button {
            appManager.playHaptic()
            showSettings.toggle()
        } label: {
#if os(macOS)
            Label("Réglages", systemImage: "slider.horizontal.3")
#else
            Label("Réglages", systemImage: "slider.horizontal.3")
#endif
        }
        .keyboardShortcut(",", modifiers: .command)
    }
}

#Preview {
    @Previewable @FocusState var isPromptFocused: Bool

    ChatView(
        currentThread: .constant(nil),
        isPromptFocused: $isPromptFocused,
        showChats: .constant(false),
        showSettings: .constant(false),
        viewModel: .init()
    )
    .environment(AppManager())
}
