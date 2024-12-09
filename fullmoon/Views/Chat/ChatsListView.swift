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
                    List {
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
                            #if os(macOS)
                            .contextMenu {
                                Button {
                                    deleteThread(thread)
                                } label: {
                                    Text("delete")
                                }
                            }
                            #endif
                            .tag(thread.id)
                        }
                        .onDelete(perform: deleteThreads)
                    }
                    #if os(iOS)
                    .listStyle(.insetGrouped)
                    #elseif os(macOS)
                    .listStyle(.sidebar)
                    #endif
                }
            }
            .navigationTitle("chats")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $search, prompt: "search")
            #elseif os(macOS)
            .searchable(text: $search, placement: .sidebar, prompt: "search")
            #endif
            .toolbar {
                #if os(iOS)
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
                    .keyboardShortcut("N", modifiers: [.command])
                }
                #elseif os(macOS)
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { setCurrentThread(nil) }) {
                        Label("new", systemImage: "plus")
                    }
                    .keyboardShortcut("N", modifiers: [.command])
                }
                #endif
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
                    setCurrentThread(nil)
                }
            }
            
            // Adding a delay fixes a crash on iOS following a deletion
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                modelContext.delete(thread)
            }
        }
    }
    
    private func deleteThread(_ thread: Thread) {
        if let currentThread = currentThread {
            if currentThread.id == thread.id {
                setCurrentThread(nil)
            }
        }
        modelContext.delete(thread)
    }
    
    private func setCurrentThread(_ thread: Thread? = nil) {
        
        currentThread = thread
        if let thread {
            selection = thread.id
        } else {
            selection = nil
        }
        isPromptFocused = true
        #if os(iOS)
        dismiss()
        #endif
        appManager.playHaptic()
    }
}

#Preview {
    @FocusState var isPromptFocused: Bool
    ChatsListView(currentThread: .constant(nil), isPromptFocused: $isPromptFocused)
}
