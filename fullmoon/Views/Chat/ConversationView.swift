//
//  ConversationView.swift
//  fullmoon
//
//  Created by Xavier on 16/12/2024.
//

import MarkdownUI
import AIEffectsKit
import SwiftUI

struct ConversationView: View {
    @Environment(AppManager.self) private var appManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let thread: Thread
    var onRegenerate: ((Message) -> Void)? = nil
    var onRetry: ((Message) -> Void)? = nil
    var onEdit: ((Message) -> Void)? = nil
    var onDelete: ((Message) -> Void)? = nil
    var onBranch: ((Message) -> Void)? = nil
    var generatingMessageID: UUID? = nil
    var generationPhase = AIPhase.idle

    @State private var followsResponse = true
    @State private var isUserScrolling = false
    private let bottomAnchorID = "conversation_bottom_anchor"

    var body: some View {
        let sorted = thread.sortedMessages
        let isGenerating = generatingMessageID != nil

        ScrollViewReader { proxy in
            ZStack(alignment: .bottom) {
                ScrollView(.vertical) {
                    LazyVStack(alignment: .leading, spacing: appManager.appearance.density.spacing) {
                        ForEach(sorted) { message in
                            MessageView(
                                message: message,
                                isStreaming: message.id == generatingMessageID,
                                generationPhase: message.id == generatingMessageID ? generationPhase : nil,
                                onRegenerate: onRegenerate.map { action in { action(message) } },
                                onRetry: onRetry.map { action in { action(message) } },
                                onEdit: onEdit.map { action in { action(message) } },
                                onDelete: onDelete.map { action in { action(message) } },
                                onBranch: onBranch.map { action in { action(message) } }
                            )
                            .id(message.id)
                            .transition(.opacity)
                        }

                        // Bottom anchor for stable scrolling
                        Color.clear
                            .frame(height: 8)
                            .id(bottomAnchorID)
                    }
                    .padding(DesignTokens.pageInset)
                    .frame(maxWidth: appManager.appearance.contentWidth)
                    .frame(maxWidth: .infinity)
                    .animation(
                        reduceMotion || appManager.appearance.reduceAnimations ? nil : .easeInOut(duration: 0.18),
                        value: thread.messages.count
                    )
                }
                .modifier(ConversationScrollTracking(followsResponse: $followsResponse, isUserScrolling: $isUserScrolling))
                #if os(iOS)
                .scrollDismissesKeyboard(.interactively)
                #endif

                // Floating "Back to bottom" Pill
                if !followsResponse {
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                            followsResponse = true
                            proxy.scrollTo(bottomAnchorID, anchor: .bottom)
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.down")
                                .font(.caption.weight(.bold))
                            if isGenerating {
                                Text("Nouveaux messages")
                                    .font(.caption.weight(.medium))
                            } else {
                                Text("Dernier message")
                                    .font(.caption.weight(.medium))
                            }
                        }
                        .foregroundStyle(appManager.appTintColor.getColor())
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background {
                            Capsule()
                                .fill(.ultraThinMaterial)
                        }
                        .overlay {
                            Capsule()
                                .strokeBorder(.secondary.opacity(0.2), lineWidth: 0.5)
                        }
                        .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 12)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .accessibilityLabel(isGenerating ? "Nouveaux messages reçus, faire défiler vers le bas" : "Faire défiler vers le bas")
                }
            }
            .onChange(of: thread.id) {
                followsResponse = true
                proxy.scrollTo(bottomAnchorID, anchor: .bottom)
            }
            .onChange(of: generatingMessageID) {
                guard followsResponse, let id = generatingMessageID,
                      thread.messages.contains(where: { $0.id == id }) else { return }
                proxy.scrollTo(bottomAnchorID, anchor: .bottom)
            }
        }
    }
}

private struct ConversationScrollTracking: ViewModifier {
    @Binding var followsResponse: Bool
    @Binding var isUserScrolling: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 18.0, macOS 15.0, visionOS 2.0, *) {
            content
                .defaultScrollAnchor(.bottom, for: .initialOffset)
                .onScrollPhaseChange { _, phase in
                    isUserScrolling = phase != .idle
                }
                .onScrollGeometryChange(for: Bool.self) { geometry in
                    geometry.contentOffset.y + geometry.containerSize.height >= geometry.contentSize.height - 80
                } action: { _, isNearBottom in
                    if isUserScrolling {
                        followsResponse = isNearBottom
                    } else if isNearBottom {
                        followsResponse = true
                    }
                }
        } else {
            content
                .defaultScrollAnchor(.bottom)
                .simultaneousGesture(DragGesture().onChanged { _ in followsResponse = false })
        }
    }
}

#Preview {
    let thread = Thread()
    thread.messages = [
        Message(role: .user, content: "Comment garder mes idées organisées ?"),
        Message(role: .assistant, content: "Commencez par **une idée par note**.\n\n- Capturez sans trier.\n- Relisez chaque semaine.\n- Choisissez une prochaine action.\n\n```swift\nlet prochaineAction = \"Faire un premier pas\"\n```")
    ]
    return ConversationView(thread: thread)
        .environment(AppManager())
        .frame(width: 760, height: 600)
}
