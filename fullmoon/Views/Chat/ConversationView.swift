//
//  ConversationView.swift
//  fullmoon
//
//  Created by Xavier on 16/12/2024.
//

import MarkdownUI
import SwiftUI

struct ConversationView: View {
    @Environment(AppManager.self) private var appManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let thread: Thread
    var onRegenerate: ((Message) -> Void)? = nil
    var generatingMessageID: UUID? = nil
    @State private var followsResponse = true
    @State private var isUserScrolling = false

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                LazyVStack(alignment: .leading, spacing: appManager.appearance.density.spacing) {
                    ForEach(thread.sortedMessages) { message in
                        VStack(alignment: .leading) {
                            if message.id == generatingMessageID && message.content.isEmpty {
                                ProgressView("Noctis réfléchit…")
                                    .controlSize(.small)
                            } else {
                                MessageView(
                                    message: message,
                                    isStreaming: message.id == generatingMessageID,
                                    onRegenerate: message.role == .assistant && generatingMessageID == nil ? onRegenerate.map { action in { action(message) } } : nil
                                )
                            }
                        }
                        .id(message.id)
                        .transition(.opacity)
                    }
                }
                .padding(DesignTokens.pageInset)
                .frame(maxWidth: appManager.appearance.contentWidth)
                .frame(maxWidth: .infinity)
                .animation(reduceMotion || appManager.appearance.reduceAnimations ? nil : .easeInOut(duration: 0.18), value: thread.messages.count)
            }
            .overlay(alignment: .bottomTrailing) {
                if !followsResponse {
                    Button {
                        followsResponse = true
                        if let id = thread.sortedMessages.last?.id { proxy.scrollTo(id, anchor: .bottom) }
                    } label: {
                        Label("Dernier message", systemImage: "arrow.down")
                    }
                    .buttonStyle(.borderedProminent)
                    .padding()
                }
            }
            .modifier(ConversationScrollTracking(followsResponse: $followsResponse, isUserScrolling: $isUserScrolling))
            .onChange(of: thread.id) {
                followsResponse = true
                if let id = thread.sortedMessages.last?.id { proxy.scrollTo(id, anchor: .bottom) }
            }
            .onChange(of: generatingMessageID) {
                guard let id = generatingMessageID, thread.messages.contains(where: { $0.id == id }) else { return }
                followsResponse = true
                proxy.scrollTo(id, anchor: .bottom)
            }
            .onChange(of: thread.sortedMessages.last?.content) {
                if followsResponse, let id = generatingMessageID { proxy.scrollTo(id, anchor: .bottom) }
            }
            #if os(iOS)
                .scrollDismissesKeyboard(.interactively)
            #endif
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
                    if isUserScrolling { followsResponse = isNearBottom }
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
    let _ = thread.messages = [
        Message(role: .user, content: "Comment garder mes idées organisées ?"),
        Message(role: .assistant, content: "Commencez par **une idée par note**.\n\n- Capturez sans trier.\n- Relisez chaque semaine.\n- Choisissez une prochaine action.\n\n```swift\nlet prochaineAction = \"Faire un premier pas\"\n```")
    ]
    ConversationView(thread: thread)
        .environment(AppManager())
        .frame(width: 760, height: 600)
}
