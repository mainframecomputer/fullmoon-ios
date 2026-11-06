//
//  ChatView.swift
//  fullmoon
//
//  Created by Jordan Singer on 10/4/24.
//

import SwiftData
import SwiftUI

struct ChatView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppManager.self) private var appManager
    @Binding var currentThread: Thread?
    var isPromptFocused: FocusState<Bool>.Binding
    @Binding var showChats: Bool
    @Binding var showSettings: Bool
    @Bindable var viewModel: ViewModel

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                conversationContent

                connectionStatus

                Composer(
                    viewModel: viewModel,
                    isPromptFocused: isPromptFocused,
                    onSend: {
                        viewModel.send(to: currentThread, in: modelContext) { currentThread = $0 }
                    }
                )
                .frame(maxWidth: appManager.appearance.contentWidth)
                .padding(.horizontal, DesignTokens.pageInset)
                .padding(.bottom, DesignTokens.pageInset)
            }
            .background(appManager.appearance.theme.background)
            .navigationTitle(viewModel.chatTitle(for: currentThread))
            #if os(iOS) || os(visionOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                chatToolbar
            }
        }
        .onAppear {
            viewModel.updateThreadSelection(currentThread)
        }
        .onDisappear {
            viewModel.stop()
        }
        .onChange(of: currentThread?.id) {
            viewModel.updateThreadSelection(currentThread)
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
            VStack(spacing: 6) {
                if let error = viewModel.submissionError {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .font(.caption)
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                        Spacer()
                        if viewModel.lastFailedPrompt != nil {
                            Button("Restaurer le texte") {
                                viewModel.restoreLastFailedPrompt()
                                isPromptFocused = true
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.mini)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                ChatInputView(
                    prompt: $viewModel.prompt,
                    isEnabled: viewModel.isInputEnabled,
                    isSending: viewModel.isSending,
                    isStopping: viewModel.isStopping,
                    isLoading: viewModel.isLoading,
                    status: viewModel.connectionMessage,
                    onSend: onSend,
                    onStop: { viewModel.stop() },
                    focusState: $isPromptFocused
                )
            }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var conversationContent: some View {
        if let currentThread {
            ConversationView(
                thread: currentThread,
                onRegenerate: { message in
                    viewModel.regenerate(message, in: currentThread, context: modelContext)
                },
                onRetry: { message in
                    viewModel.regenerate(message, in: currentThread, context: modelContext)
                },
                onEdit: { message in
                    viewModel.editUserMessage(message, in: currentThread, context: modelContext)
                    isPromptFocused.wrappedValue = true
                },
                onDelete: { message in
                    viewModel.deleteMessage(message, in: currentThread, context: modelContext)
                },
                onBranch: { message in
                    viewModel.createBranch(from: message, in: currentThread, context: modelContext) { self.currentThread = $0 }
                },
                generatingMessageID: viewModel.generatingMessageID,
                generationPhase: viewModel.generationPhase
            )
        } else {
            emptyConversation
        }
    }

    private var emptyConversation: some View {
        WelcomeConversation { suggestion in
            viewModel.prompt = suggestion
            isPromptFocused.wrappedValue = true
        }
    }

    // MARK: - Connection Status (Subtle floating capsule when not ready)

    @ViewBuilder
    private var connectionStatus: some View {
        if !viewModel.isConnected {
            HStack(spacing: 8) {
                if viewModel.isLoading {
                    ProgressView()
                        .controlSize(.mini)
                } else {
                    Image(systemName: "wifi.slash")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Text(viewModel.connectionMessage)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                if !viewModel.isLoading && viewModel.submissionError != nil {
                    Button("Réessayer") {
                        Task { await viewModel.loadModel() }
                    }
                    .font(.caption2.weight(.semibold))
                    .buttonStyle(.plain)
                    .foregroundStyle(appManager.appTintColor.getColor())
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(.quaternary.opacity(0.3), in: Capsule())
            .padding(.bottom, 4)
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
                .accessibilityLabel("Liste des conversations")
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
            Label("Réglages", systemImage: "slider.horizontal.3")
        }
        .accessibilityLabel("Ouvrir les réglages")
        .keyboardShortcut(",", modifiers: .command)
    }
}

// MARK: - Previews

#Preview("Conversation vide") {
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

#Preview("Conversation active") {
    @Previewable @FocusState var isPromptFocused: Bool
    let thread = Thread()
    thread.messages = [
        Message(role: .user, content: "Explique-moi le protocole Sendable en Swift."),
        Message(role: .assistant, content: "Le protocole `Sendable` indique qu'un type peut être partagé en toute sécurité à travers des limites concurrentes.\n\n```swift\nstruct UserProfile: Sendable {\n    let id: UUID\n    let username: String\n}\n```")
    ]
    return ChatView(
        currentThread: .constant(thread),
        isPromptFocused: $isPromptFocused,
        showChats: .constant(false),
        showSettings: .constant(false),
        viewModel: .init()
    )
    .environment(AppManager())
}
