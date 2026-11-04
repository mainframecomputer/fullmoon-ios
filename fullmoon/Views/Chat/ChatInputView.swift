//
//  ChatInputView.swift
//  fullmoon
//

import SwiftUI
#if os(macOS)
import AppKit
#endif

struct ChatInputView: View {
    @Environment(AppManager.self) private var appManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var prompt: String
    @FocusState.Binding var isPromptFocused: Bool

    let isEnabled: Bool
    let canSend: Bool
    var isLoading = false
    var isSending = false
    var isStopping = false
    var onStop: (() -> Void)? = nil
    var sendUnavailableHint: LocalizedStringKey = "Enter a message to send."
    let onSend: () -> Void

    private var sendEnabled: Bool {
        isEnabled && canSend && !isLoading && !isSending
    }

    private var status: LocalizedStringKey {
        if isLoading { return "Loading model" }
        if isSending { return "Sending message" }
        if !isEnabled { return "Model unavailable" }
        if !canSend { return sendUnavailableHint }
        return "Ready to send"
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField("Écrivez à Fullmoon…", text: $prompt, axis: .vertical)
                .font(.body)
                .textFieldStyle(.plain)
                .lineLimit(1...6)
                .focused($isPromptFocused)
                .padding(.leading, 12)
                .padding(.vertical, 10)
                .frame(minHeight: 44)
                .disabled(!isEnabled || isLoading)
                .accessibilityLabel("Message")
                .accessibilityHint(status)
                .onSubmit {
                    if sendEnabled { onSend() }
                }
#if os(macOS)
                .onKeyPress(.return, phases: .down) { press in
                    if press.modifiers.contains(.shift) {
                        guard let editor = NSApp.keyWindow?.firstResponder as? NSTextView else { return .ignored }
                        editor.insertNewlineIgnoringFieldEditor(nil)
                        return .handled
                    }
                    if sendEnabled { onSend() }
                    return .handled
                }
#endif

            Button {
                if isSending {
                    onStop?()
                } else if sendEnabled {
                    onSend()
                }
            } label: {
                ZStack {
                    Image(systemName: isSending ? "stop.circle.fill" : "arrow.up.circle.fill")
                        .font(.title2)
                        .opacity(isLoading || isStopping ? 0 : 1)

                    if isLoading || isStopping {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .disabled(isSending ? (isStopping || onStop == nil) : !sendEnabled)
            .accessibilityLabel(isSending ? "Stop response" : "Send message")
            .accessibilityValue(status)
            .accessibilityHint(isSending ? "Stops the current response." : "Sends the message without dismissing the keyboard.")
#if os(macOS)
            .keyboardShortcut(.return, modifiers: .command)
#endif
        }
        .animation(reduceMotion || appManager.appearance.reduceAnimations ? nil : .easeInOut(duration: 0.18), value: isSending)
        .padding(6)
        .background {
            ComposerBackground()
        }
    }
}

/// Keep appearance changes in the background so the editor retains its identity and selection.
private struct ComposerBackground: View {
    @Environment(AppManager.self) private var appManager
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: DesignTokens.composerRadius, style: .continuous)

        if reduceTransparency || contrast == .increased || !appManager.appearance.useGlass {
            shape.fill(.background)
                .overlay {
                    shape.strokeBorder(.primary, lineWidth: 1)
                }
        } else if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            Color.clear
                .glassEffect(.regular, in: shape)
        } else {
            shape.fill(.regularMaterial)
        }
    }
}

private struct ComposerPreview: View {
    @State private var prompt: String
    @FocusState private var isPromptFocused: Bool

    var isEnabled = true
    var isLoading = false
    var isSending = false

    init(text: String = "", isEnabled: Bool = true, isLoading: Bool = false, isSending: Bool = false) {
        _prompt = State(initialValue: text)
        self.isEnabled = isEnabled
        self.isLoading = isLoading
        self.isSending = isSending
    }

    var body: some View {
        ChatInputView(
            prompt: $prompt,
            isPromptFocused: $isPromptFocused,
            isEnabled: isEnabled,
            canSend: prompt.contains { !$0.isWhitespace },
            isLoading: isLoading,
            isSending: isSending,
            onSend: { prompt = "" }
        )
        .padding()
        .environment(AppManager())
    }
}

#Preview("Empty · Light") {
    ComposerPreview()
        .preferredColorScheme(.light)
}

#Preview("Message · Dark") {
    ComposerPreview(text: "Help me plan a quiet weekend under the stars.")
        .preferredColorScheme(.dark)
}

#Preview("Model unavailable") {
    ComposerPreview(isEnabled: false)
}

#Preview("Loading model") {
    ComposerPreview(isEnabled: false, isLoading: true)
}

#Preview("Sending") {
    ComposerPreview(text: "Tell me about the moon.", isSending: true)
}

#Preview("Long message · Dynamic Type") {
    ComposerPreview(text: String(repeating: "A longer message that remains editable and scrollable.\n", count: 8))
        .environment(\.dynamicTypeSize, .accessibility3)
}
