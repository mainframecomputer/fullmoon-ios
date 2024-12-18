//
//  ConversationView.swift
//  fullmoon
//
//  Created by Xavier on 16/12/2024.
//

import MarkdownUI
import SwiftUI

struct MessageView: View {
    let message: Message

    var body: some View {
        HStack {
            if message.role == .user { Spacer() }
            Markdown(message.content)
                .textSelection(.enabled)
                .if(message.role == .user) { view in
                    view
                    #if os(iOS)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    #else
                    .padding(.horizontal, 16 * 2 / 3)
                    .padding(.vertical, 8)
                    #endif
                    .background(platformBackgroundColor)
                    #if os(iOS)
                        .mask(RoundedRectangle(cornerRadius: 24))
                    #elseif os(macOS)
                        .mask(RoundedRectangle(cornerRadius: 16))
                    #endif
                }
                .padding(message.role == .user ? .leading : .trailing, 48)
            if message.role == .assistant { Spacer() }
        }
    }

    let platformBackgroundColor: Color = {
        #if os(iOS) || os(visionOS)
        return Color(UIColor.secondarySystemBackground)
        #elseif os(macOS)
        return Color(NSColor.secondarySystemFill)
        #endif
    }()
}

struct ConversationView: View {
    @Environment(LLMEvaluator.self) var llm
    @EnvironmentObject var appManager: AppManager
    let thread: Thread

    @State private var scrollID: String?
    @State private var scrollInterrupted = false

    var body: some View {
        ScrollViewReader { scrollView in
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(thread.sortedMessages) { message in
                        MessageView(message: message)
                            .padding()
                            .id(message.id.uuidString)
                    }

                    if llm.running && !llm.output.isEmpty {
                        MessageView(message: Message(role: .assistant, content: llm.output + " 🌕"))
                            .padding()
                            .id("output")
                            .onAppear {
                                print("output appeared")
                                scrollInterrupted = false // reset interruption when a new output begins
                            }
                    }

                    Rectangle()
                        .fill(.clear)
                        .frame(height: 1)
                        .id("bottom")
                }
                .scrollTargetLayout()
                
            }
            .scrollPosition(id: $scrollID, anchor: .bottom)
            .onChange(of: llm.output) { _, _ in
                // auto scroll to bottom
                if !scrollInterrupted {
                    scrollView.scrollTo("bottom")
                }
                appManager.playHaptic()
            }
            .onChange(of: scrollID) { old, new in
                // interrupt auto scroll to bottom if user scrolls away
                if llm.running {
                    scrollInterrupted = true
                }
            }
        }
        .defaultScrollAnchor(.bottom)
        #if os(iOS)
        .scrollDismissesKeyboard(.interactively)
        #endif
    }
}

#Preview {
    ConversationView(thread: Thread())
        .environment(LLMEvaluator())
        .environmentObject(AppManager())
}
