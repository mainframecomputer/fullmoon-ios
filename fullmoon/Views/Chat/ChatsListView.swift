//
//  ChatsListView.swift
//  fullmoon
//
//  Created by Jordan Singer on 10/5/24.
//

import SwiftUI
import SwiftData

struct ChatsListView: View {
    @EnvironmentObject var appManager: AppManager
    @Environment(\.dismiss) var dismiss
    @Binding var currentThread: Thread?
    @FocusState.Binding var isPromptFocused: Bool
    @Environment(\.modelContext) var modelContext
    @Query(sort: \Thread.timestamp, order: .reverse) var threads: [Thread]
    @State var search = ""
    @State var selection: UUID?
    
    var body: some View {
        NavigationStack {
            Group {
                if filteredThreads.count == 0 {
                    ContentUnavailableView {
                        Label(threads.count == 0 ? "no chats yet" : "no results", systemImage: "message")
                    }
                } else {
                    List(selection: $selection) {
                        ForEach(filteredThreads) { thread in
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
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                setCurrentThread(thread)
                            }
                            .tag(thread.id)
                        }
                        .onDelete(perform: deleteThreads)
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .searchable(text: $search, prompt: "search")
            .navigationTitle("chats")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if appManager.userInterfaceIdiom == .phone {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark")
                        }
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { setCurrentThread(nil) }) {
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
        if let thread {
            selection = thread.id
        } else {
            selection = nil
        }
        isPromptFocused = true
        dismiss()
        appManager.playHaptic()
    }
}

#Preview {
    @FocusState var isPromptFocused: Bool
    ChatsListView(currentThread: .constant(nil), isPromptFocused: $isPromptFocused)
}
