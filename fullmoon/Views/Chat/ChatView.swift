//
//  ChatView.swift
//  fullmoon
//
//  Created by Jordan Singer on 12/3/24.
//

import SwiftUI
import MarkdownUI

struct ChatView: View {
    @EnvironmentObject var appManager: AppManager
    @Environment(\.modelContext) var modelContext
    @Binding var currentThread: Thread?
    @Environment(LLMEvaluator.self) var llm
    @Namespace var bottomID
    @State var showModelPicker = false
    @State var prompt = ""
    @FocusState.Binding var isPromptFocused: Bool
    @Binding var showChats: Bool
    @Binding var showSettings: Bool
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let currentThread = currentThread {
                    ScrollViewReader { scrollView in
                        ScrollView(.vertical) {
                            VStack(alignment: .leading, spacing: 0) {
                                ForEach(currentThread.sortedMessages) { message in
                                    HStack {
                                        if message.role == .user {
                                            Spacer()
                                        }
                                        
                                        Markdown(message.content)
                                            .textSelection(.enabled)
                                            .if(message.role == .user) { view in
                                                view
                                                    .padding(.horizontal, 16)
                                                    .padding(.vertical, 12)
                                                    .background(Color(UIColor.secondarySystemBackground))
                                                    .mask(RoundedRectangle(cornerRadius: 24))
                                            }
                                            .padding(message.role == .user ? .leading : .trailing, 48)
                                        
                                        if message.role == .assistant {
                                            Spacer()
                                        }
                                    }
                                    .padding()
                                }
                                
                                if llm.running && !llm.output.isEmpty {
                                    HStack {
                                        Markdown(llm.output)
                                            .textSelection(.enabled)
                                            .padding(.trailing, 48)
                                        
                                        Spacer()
                                    }
                                    .padding()
                                }
                            }
                            
                            Rectangle()
                                .fill(.clear)
                                .frame(height: 1)
                                .id(bottomID)
                        }
                        .onChange(of: llm.output) { _, _ in
                            scrollView.scrollTo(bottomID)
                            appManager.playHaptic()
                        }
                    }
                    .defaultScrollAnchor(.bottom)
                    .scrollDismissesKeyboard(.interactively)
                } else {
                    Spacer()
                    Image(systemName: appManager.getMoonPhaseIcon())
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 32, height: 32)
                        .foregroundStyle(.quaternary)
                    Spacer()
                }
                
                HStack(alignment: .bottom) {
                    Button {
                        appManager.playHaptic()
                        showModelPicker.toggle()
                    } label: {
                        Group {
                            Image(systemName: "chevron.up")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 16)
                                .tint(.primary)
                        }
                        .frame(width: 48, height: 48)
                        .background(
                            Circle()
                                .fill(Color(UIColor.secondarySystemBackground))
                        )
                    }
                    
                    HStack(alignment: .bottom, spacing: 0) {
                        TextField("message", text: $prompt, axis: .vertical)
                            .focused($isPromptFocused)
                            .textFieldStyle(.plain)
                            .padding(.horizontal)
                            .if(appManager.userInterfaceIdiom == .pad || appManager.userInterfaceIdiom == .mac) { view in
                                view
                                    .onSubmit {
                                        generate()
                                    }
                                    .submitLabel(.send)
                            }
                            .padding(.vertical, 8)
                            .frame(minHeight: 48)
                        Button {
                            generate()
                        } label: {
                            Image(systemName: "arrow.up.circle.fill")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 24, height: 24)
                        }
                        .disabled(llm.running || prompt.isEmpty)
                        .padding(.trailing)
                        .padding(.bottom, 12)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(Color(UIColor.secondarySystemBackground))
                    )
                }
                .padding()
            }
            .navigationTitle(chatTitle)
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showModelPicker) {
                NavigationStack {
                    ModelsSettingsView()
                        .environment(llm)
                }
                .presentationDragIndicator(.visible)
                .if(appManager.userInterfaceIdiom == .phone) { view in
                    view.presentationDetents([.fraction(0.4)])
                }
            }
            .toolbar {
                if appManager.userInterfaceIdiom == .phone {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(action: {
                            appManager.playHaptic()
                            showChats.toggle()
                        }) {
                            Image(systemName: "list.bullet")
                        }
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        appManager.playHaptic()
                        showSettings.toggle()
                    }) {
                        Image(systemName: "gear")
                    }
                }
            }
        }
    }
    
    var chatTitle: String {
        if let currentThread = currentThread {
            if let firstMessage = currentThread.sortedMessages.first {
                return firstMessage.content
            }
        }
        
        return "chat"
    }

    private func generate() {
        if !prompt.isEmpty {
            if currentThread == nil {
                let newThread = Thread()
                currentThread = newThread
                modelContext.insert(newThread)
                try? modelContext.save()
            }
            
            if let currentThread = currentThread {
                Task {
                    let message = prompt
                    prompt = ""
                    appManager.playHaptic()
                    sendMessage(Message(role: .user, content: message, thread: currentThread))
                    isPromptFocused = true
                    if let modelName = appManager.currentModelName {
                        let output = await llm.generate(modelName: modelName, thread: currentThread, systemPrompt: appManager.systemPrompt)
                        sendMessage(Message(role: .assistant, content: output, thread: currentThread))
                    }
                }
            }
        }
    }
    
    private func sendMessage(_ message: Message) {
        appManager.playHaptic()
        modelContext.insert(message)
        try? modelContext.save()
    }
    
    private func copyToClipboard(_ string: String) {
        UIPasteboard.general.string = string
    }
}

#Preview {
    @FocusState var isPromptFocused: Bool
    ChatView(currentThread: .constant(nil), isPromptFocused: $isPromptFocused, showChats: .constant(false), showSettings: .constant(false))
}
