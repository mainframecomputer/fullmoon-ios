//
//  ContentView.swift
//  fullmoon
//
//  Created by Jordan Singer on 10/4/24.
//

import SwiftData
import SwiftUI

struct ContentView: View {
    private var idiom : UIUserInterfaceIdiom { UIDevice.current.userInterfaceIdiom }
    @EnvironmentObject var appManager: AppManager
    @Environment(\.modelContext) var modelContext
    @Environment(LLMEvaluator.self) var llm
    @State var showOnboarding = false
    @State var showSettings = false
    @State var showChats = false
    @State var showModelPicker = false
    @State var prompt = ""
    @FocusState var isPromptFocused: Bool
    @State var currentThread: Thread?
    @Namespace var bottomID

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
                                        
                                        Text(try! AttributedString(markdown: message.content.trimmingCharacters(in: .whitespacesAndNewlines),
                                             options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
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
                                        Text(try! AttributedString(markdown: llm.output.trimmingCharacters(in: .whitespacesAndNewlines) + " 🌕",
                                             options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
                                            .textSelection(.enabled)
                                            .multilineTextAlignment(.leading)
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
                            .if(idiom == .pad || idiom == .mac) { view in
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
            .toolbarRole(.editor)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: {
                        appManager.playHaptic()
                        showChats.toggle()
                    }) {
                        Image(systemName: "list.bullet")
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
        .task {
            if appManager.installedModels.count == 0 {
                showOnboarding.toggle()
            } else {
                isPromptFocused = true
                // load the model
                if let modelName = appManager.currentModelName {
                    _ = try? await llm.load(modelName: modelName)
                }
            }
        }
        .gesture(
            DragGesture()
                .onChanged { gesture in
                    if !showChats && gesture.startLocation.x < 20 && gesture.translation.width > 100 {
                        appManager.playHaptic()
                        showChats = true
                    }
                }
        )
        .sheet(isPresented: $showChats) {
            ChatsView(currentThread: $currentThread, isPromptFocused: $isPromptFocused)
                .environmentObject(appManager)
                .presentationDragIndicator(.hidden)
                .if(idiom == .phone) { view in
                    view.presentationDetents([.medium, .large])
                }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(currentThread: $currentThread)
                .environmentObject(appManager)
                .environment(llm)
                .presentationDragIndicator(.hidden)
                .if(idiom == .phone) { view in
                    view.presentationDetents([.medium])
                }
        }
        .sheet(isPresented: $showModelPicker) {
            NavigationStack {
                ModelsSettingsView()
                    .environment(llm)
            }
            .presentationDragIndicator(.visible)
            .if(idiom == .phone) { view in
                view.presentationDetents([.fraction(0.4)])
            }
        }
        .sheet(isPresented: $showOnboarding, onDismiss: dismissOnboarding) {
            OnboardingView(showOnboarding: $showOnboarding)
                .environment(llm)
                .interactiveDismissDisabled(appManager.installedModels.count == 0)
            
        }
        .tint(appManager.appTintColor.getColor())
        .fontDesign(appManager.appFontDesign.getFontDesign())
        .environment(\.dynamicTypeSize, appManager.appFontSize.getFontSize())
        .fontWidth(appManager.appFontWidth.getFontWidth())
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
    
    func dismissOnboarding() {
        isPromptFocused = true
    }
}

extension View {
    @ViewBuilder func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

#Preview {
    ContentView()
}
