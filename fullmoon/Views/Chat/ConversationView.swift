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

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 0) {
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
            .defaultScrollAnchor(.bottom)
            .onChange(of: thread.sortedMessages.last?.content) {
                if let id = generatingMessageID { proxy.scrollTo(id, anchor: .bottom) }
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
