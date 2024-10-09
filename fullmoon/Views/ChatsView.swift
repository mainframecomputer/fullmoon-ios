//
//  ChatsView.swift
//  fullmoon
//
//  Created by Jordan Singer on 10/5/24.
//

import SwiftUI
import SwiftData

struct ChatsView: View {
    @EnvironmentObject var appManager: AppManager
    @Environment(\.dismiss) var dismiss
    @Binding var currentThread: Thread?
    @FocusState.Binding var isPromptFocused: Bool
    @Environment(\.modelContext) var modelContext
    @Query(sort: \Thread.timestamp, order: .reverse) var threads: [Thread]
    @State var search = ""
    
    var body: some View {
        NavigationStack {
            Group {
                if filteredThreads.count == 0 {
                    ContentUnavailableView {
                        Label(threads.count == 0 ? "no chats yet" : "no results", systemImage: "message")
                    }
                } else {
                    List {
                        Section {
                            ForEach(filteredThreads) { thread in
                                Button {
                                    setCurrentThread(thread)
                                } label: {
                                    VStack(alignment: .leading) {
                                        Group {
                                            if let firstMessage = thread.sortedMessages.first {
                                                Text(firstMessage.content)
                                                    .lineLimit(1)
                                            } else {
                                                Text("untitled")
                                            }
                                        }
                                        .foregroundStyle(.primary)
                                        .font(.headline)
                                        
                                        Text("\(thread.timestamp.formatted())")
                                            .foregroundStyle(.secondary)
                                            .font(.subheadline)
                                    }
                                }
                                .tint(.primary)
                            }
                            .onDelete(perform: deleteThreads)
                        }
                    }
                }
            }
            .searchable(text: $search, prompt: "search")
            .navigationTitle("chats")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { setCurrentThread() }) {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .tint(appManager.appTintColor.getColor())
        .environment(\.dynamicTypeSize, appManager.appFontSize.getFontSize())
    }
    
    var filteredThreads: [Thread] {
        threads.filter { thread in
            search.isEmpty || thread.messages.contains { message in
                message.content.localizedCaseInsensitiveContains(search)
            }
        }
    }
    
    private func deleteThreads(at offsets: IndexSet) {
        for offset in offsets {
            let thread = threads[offset]
            
            if let currentThread = currentThread {
                if currentThread.id == thread.id {
                    setCurrentThread()
                }
            }
            
            modelContext.delete(thread)
        }
    }
    
    private func setCurrentThread(_ thread: Thread? = nil) {
        currentThread = thread
        isPromptFocused = true
        dismiss()
        let impact = UIImpactFeedbackGenerator(style: .soft)
        impact.impactOccurred()
    }
}

#Preview {
    @FocusState var isPromptFocused: Bool
    ChatsView(currentThread: .constant(nil), isPromptFocused: $isPromptFocused)
}
