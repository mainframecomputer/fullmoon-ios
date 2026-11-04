//
//  ConversationView.swift
//  fullmoon
//
//  Created by Xavier on 16/12/2024.
//

import MarkdownUI
import SwiftUI

struct ConversationView: View {
    let thread: Thread
    var generatingMessageID: UUID? = nil
    @State private var followsResponse = true
    @State private var isUserScrolling = false

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(thread.sortedMessages) { message in
                        VStack(alignment: .leading) {
                            if message.id == generatingMessageID && message.content.isEmpty {
                                ProgressView("Noctis réfléchit…")
                                    .controlSize(.small)
                            } else {
                                MessageView(message: message)
                            }
                        }
                        .padding()
                        .id(message.id)
                    }
                }
            }
            .defaultScrollAnchor(.bottom, for: .initialOffset)
            .onScrollPhaseChange { _, phase in
                isUserScrolling = phase != .idle
            }
            .onScrollGeometryChange(for: Bool.self) { geometry in
                geometry.contentOffset.y + geometry.containerSize.height >= geometry.contentSize.height - 80
            } action: { _, isNearBottom in
                if isUserScrolling { followsResponse = isNearBottom }
            }
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

#Preview {
    ConversationView(thread: Thread())
}
