//
//  ChatListRowView.swift
//  fullmoon
//
//  Created by Pedro Diogo on 26/01/2025.
//

import SwiftUI

struct ChatListRowView: View {
    @State private var isRenaming: Bool = false
    @FocusState private var isRenameTextFieldFocused: Bool
    
    var thread: Thread
    var deleteThread: (Thread) -> Void
    
    var body: some View {
        VStack(alignment: .leading) {
            ZStack {
                if isRenaming {
                    EditTitleTextField
                } else {
                    Text(thread.title ?? "untitled").lineLimit(1)
                }
            }
            .foregroundStyle(.primary)
            .font(.headline)
            
            Text("\(thread.timestamp.formatted())")
                .foregroundStyle(.secondary)
                .font(.subheadline)
        }
        #if os(macOS)
        .swipeActions {
            Button("Delete") {
                deleteThread(thread)
            }
            .tint(.red)
        }
        .contextMenu {
            Button {
                deleteThread(thread)
            } label: {
                Text("delete")
            }
            if !(isRenaming) {
                Button {
                    isRenaming = true
                } label: {
                    Text("rename")
                }
            }
        }
        .onTapGesture(count: 2) {
            isRenaming = true
        }
        #endif
        .tag(thread)
    }
    
    private var EditTitleTextField : some View {
        TextField("Title", text: Binding(
            get: { thread.title ?? "" },
            set: { thread.title = $0 }
        ))
        .focused($isRenameTextFieldFocused)
        .onAppear {
            isRenameTextFieldFocused = true
        }
        .onChange(of: isRenameTextFieldFocused) {
            if !isRenameTextFieldFocused {
                isRenaming = false
            }
        }
    }
        
}

#Preview {
    ChatListRowView(thread: Thread(), deleteThread: { _ in })
}
