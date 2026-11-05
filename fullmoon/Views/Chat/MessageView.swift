//
//  MessageView.swift
//  fullmoon
//
//  Created by Xavier on 16/12/2024.
//

import MarkdownUI
import SwiftUI

struct MessageView: View {
    @Environment(AppManager.self) private var appManager
    @Environment(\.colorScheme) private var colorScheme
    @ScaledMetric(relativeTo: .body) private var textScale = 1.0

    let message: Message
    var isStreaming = false
    var onRegenerate: (() -> Void)? = nil
    var onRetry: (() -> Void)? = nil
    var onEdit: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    var onBranch: (() -> Void)? = nil

    @State private var copied = false
    @State private var showDeleteConfirmation = false
    @State private var cursorVisible = true

    private var isUser: Bool {
        message.role == .user
    }

    private var authorName: String {
        isUser ? "Vous" : "Fullmoon"
    }

    var body: some View {
        let appearance = appManager.appearance

        HStack(alignment: .top, spacing: 10) {
            if isUser {
                Spacer(minLength: 32)
            } else if appearance.showAvatars {
                avatarView
            }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 6) {
                // Header (Author + Timestamp)
                HStack(spacing: 6) {
                    Text(authorName)
                        .font(.caption.weight(.semibold))
                    if appearance.showTimestamps {
                        Text(message.timestamp, style: .time)
                            .font(.caption2)
                    }
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, appearance.messageStyle == .bubbles ? 4 : 0)

                // Message Body Bubble / Canvas
                messageBody
                    .padding(appearance.messageStyle == .bubbles ? 14 : 4)
                    .background {
                        bubbleBackground
                    }
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.cornerRadius, style: .continuous))
                    .contentShape(RoundedRectangle(cornerRadius: DesignTokens.cornerRadius, style: .continuous))
                    .contextMenu {
                        messageContextMenu
                    }

                // Status banner if interrupted or errored
                if message.hasError {
                    errorRecoveryBar
                } else if message.isInterrupted && !isStreaming {
                    interruptedBanner
                }

                // Assistant Action Bar (Discreet, appears after completion)
                if !isUser && !isStreaming && !message.hasError {
                    assistantActions
                        .padding(.top, 2)
                        .padding(.leading, appearance.messageStyle == .bubbles ? 4 : 0)
                }
            }

            if !isUser {
                Spacer(minLength: 24)
            }
        }
        .confirmationDialog(
            "Supprimer ce message ?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Supprimer", role: .destructive) {
                onDelete?()
            }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Ce message sera définitivement retiré de la conversation.")
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    // MARK: - Avatar

    @ViewBuilder
    private var avatarView: some View {
        ZStack {
            Circle()
                .fill(.quaternary.opacity(0.6))
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(appManager.appTintColor.getColor())
        }
        .frame(width: 28, height: 28)
        .accessibilityHidden(true)
    }

    // MARK: - Message Content

    @ViewBuilder
    private var messageBody: some View {
        let appearance = appManager.appearance

        VStack(alignment: .leading, spacing: 8) {
            if isStreaming {
                if message.content.isEmpty {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Noctis réfléchit…")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                } else {
                    HStack(alignment: .bottom, spacing: 2) {
                        Text(message.content)
                            .font(.system(size: appearance.fontSize * textScale))
                            .foregroundStyle(isUser ? userTextColor : .primary)
                        
                        // Streaming blinking cursor
                        Circle()
                            .fill(appManager.appTintColor.getColor())
                            .frame(width: 7, height: 7)
                            .opacity(cursorVisible ? 1.0 : 0.2)
                            .padding(.bottom, 4)
                            .animation(.easeInOut(duration: 0.5).repeatForever(), value: cursorVisible)
                            .onAppear { cursorVisible = false }
                    }
                }
            } else {
                if isUser {
                    Text(message.content)
                        .font(.system(size: appearance.fontSize * textScale))
                        .foregroundStyle(userTextColor)
                        .textSelection(.enabled)
                } else {
                    Markdown(message.content)
                        .markdownTextStyle {
                            FontSize(appearance.fontSize * textScale)
                        }
                        .markdownBlockStyle(\.codeBlock) { configuration in
                            MessageCodeBlock(configuration: configuration)
                        }
                        .textSelection(.enabled)
                }
            }
        }
    }

    // MARK: - Bubble Background

    @ViewBuilder
    private var bubbleBackground: some View {
        let appearance = appManager.appearance

        if appearance.messageStyle == .bubbles {
            if isUser {
                RoundedRectangle(cornerRadius: DesignTokens.cornerRadius, style: .continuous)
                    .fill(appManager.appTintColor.getColor().opacity(userBubbleOpacity))
            } else {
                RoundedRectangle(cornerRadius: DesignTokens.cornerRadius, style: .continuous)
                    .fill(assistantBubbleFill)
                    .overlay {
                        RoundedRectangle(cornerRadius: DesignTokens.cornerRadius, style: .continuous)
                            .strokeBorder(Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.05), lineWidth: 0.5)
                    }
            }
        }
    }

    private var userBubbleOpacity: Double {
        switch appManager.appearance.intensity {
        case .subtle: return 0.14
        case .balanced: return 0.22
        case .expressive: return 0.32
        }
    }

    private var assistantBubbleFill: Color {
        #if os(macOS)
        return Color(nsColor: .controlBackgroundColor).opacity(0.8)
        #else
        return Color(uiColor: .secondarySystemBackground)
        #endif
    }

    private var userTextColor: Color {
        .primary
    }

    // MARK: - Error & Interrupted States

    @ViewBuilder
    private var errorRecoveryBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.caption)
            Text("La réponse n’a pas pu aboutir")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            if let retryAction = onRetry ?? onRegenerate {
                Button(action: retryAction) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                        Text("Réessayer")
                    }
                    .font(.caption.weight(.medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    @ViewBuilder
    private var interruptedBanner: some View {
        HStack(spacing: 6) {
            Image(systemName: "stop.circle")
                .font(.caption2)
            Text("Génération interrompue")
                .font(.caption2)
            Spacer()
            if let onRegenerate {
                Button("Reprendre", action: onRegenerate)
                    .font(.caption2.weight(.medium))
            }
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    // MARK: - Assistant Actions Strip

    @ViewBuilder
    private var assistantActions: some View {
        HStack(spacing: 8) {
            // Copy
            Button {
                copyContent()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    if copied {
                        Text("Copié").font(.caption2)
                    }
                }
                .font(.caption)
                .foregroundStyle(copied ? Color.green : Color.secondary)
                .frame(minWidth: 32, minHeight: 32)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Copier le message")

            // Regenerate
            if let onRegenerate {
                Button(action: onRegenerate) {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 32, minHeight: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Régénérer la réponse")
            }

            // Share
            ShareLink(item: message.content) {
                Image(systemName: "square.and.arrow.up")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 32, minHeight: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Partager ce message")
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Context Menu

    @ViewBuilder
    private var messageContextMenu: some View {
        Button {
            copyContent()
        } label: {
            Label("Copier le texte", systemImage: "doc.on.doc")
        }

        ShareLink(item: message.content) {
            Label("Partager", systemImage: "square.and.arrow.up")
        }

        if isUser {
            if let onEdit {
                Button(action: onEdit) {
                    Label("Modifier la demande", systemImage: "pencil")
                }
            }
            if let onRetry {
                Button(action: onRetry) {
                    Label("Renvoyer", systemImage: "arrow.clockwise")
                }
            }
        } else {
            if let onRegenerate {
                Button(action: onRegenerate) {
                    Label("Régénérer", systemImage: "arrow.clockwise")
                }
            }
            if let onBranch {
                Button(action: onBranch) {
                    Label("Créer une variante", systemImage: "arrow.triangle.branch")
                }
            }
        }

        Divider()

        if onDelete != nil {
            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                Label("Supprimer", systemImage: "trash")
            }
        }
    }

    // MARK: - Helpers

    private func copyContent() {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(message.content, forType: .string)
        #else
        UIPasteboard.general.string = message.content
        #endif
        appManager.playHaptic()
        withAnimation(.easeInOut(duration: 0.2)) {
            copied = true
        }
        Task {
            try? await Task.sleep(for: .seconds(2))
            copied = false
        }
    }

    private var accessibilityDescription: String {
        var desc = "\(authorName)"
        if appManager.appearance.showTimestamps {
            desc += ", à \(message.timestamp.formatted(date: .omitted, time: .shortened))"
        }
        if isStreaming {
            desc += ", en cours de réponse: \(message.content)"
        } else if message.hasError {
            desc += ", échec: \(message.content)"
        } else if message.isInterrupted {
            desc += ", interrompu: \(message.content)"
        } else {
            desc += ": \(message.content)"
        }
        return desc
    }
}
