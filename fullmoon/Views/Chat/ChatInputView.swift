//
//  ChatInputView.swift
//  fullmoon
//
//  Created by Xavier on 16/12/2024.
//

import SwiftUI

struct ChatInputView: View {
    @Environment(AppManager.self) private var appManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .body) private var textScale = 1.0

    @Binding var prompt: String
    var isEnabled: Bool
    var isSending = false
    var isStopping = false
    var isLoading = false
    var status: String
    var onSend: () -> Void
    var onStop: (() -> Void)? = nil
    var focusState: FocusState<Bool>.Binding

    private var sendEnabled: Bool {
        isEnabled && !isSending && !isLoading && prompt.contains { !$0.isWhitespace }
    }

    var body: some View {
        let appearance = appManager.appearance

        HStack(alignment: .bottom, spacing: 10) {
            TextField("Écrivez à Fullmoon…", text: $prompt, axis: .vertical)
                .font(.system(size: appearance.fontSize * textScale))
                .lineLimit(1...6)
                .textFieldStyle(.plain)
                .focused(focusState)
                .disabled(!isEnabled && !isSending)
                .padding(.leading, 14)
                .padding(.vertical, 10)
                .accessibilityLabel("Message")
                .accessibilityHint(status)
                .onSubmit {
                    if sendEnabled {
                        appManager.playHaptic()
                        onSend()
                    }
                }
                #if os(macOS)
                .onKeyPress(.return, phases: .down) { press in
                    if press.modifiers.contains(.shift) {
                        guard let editor = NSApp.keyWindow?.firstResponder as? NSTextView else { return .ignored }
                        editor.insertNewlineIgnoringFieldEditor(nil)
                        return .handled
                    }
                    if sendEnabled {
                        appManager.playHaptic()
                        onSend()
                        return .handled
                    }
                    return .ignored
                }
                #endif

            // Dynamic Action Button (Send / Stop / Loading)
            Button {
                appManager.playHaptic()
                if isSending {
                    onStop?()
                } else if sendEnabled {
                    onSend()
                }
            } label: {
                ZStack {
                    if isLoading || isStopping {
                        ProgressView()
                            .controlSize(.small)
                    } else if isSending {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 32, height: 32)
                            .background(Color.red.gradient, in: Circle())
                    } else {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(sendEnabled ? .white : Color.secondary.opacity(0.5))
                            .frame(width: 32, height: 32)
                            .background(
                                sendEnabled
                                    ? AnyShapeStyle(appManager.appTintColor.getColor().gradient)
                                    : AnyShapeStyle(Color.secondary.opacity(0.12)),
                                in: Circle()
                            )
                    }
                }
                .frame(width: 44, height: 44)
                .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(isSending ? (isStopping || onStop == nil) : !sendEnabled)
            .accessibilityLabel(isSending ? "Arrêter la génération" : "Envoyer le message")
            .accessibilityValue(status)
            .accessibilityHint(isSending ? "Arrête la réponse en cours." : "Envoie votre demande au modèle local.")
            #if os(macOS)
            .keyboardShortcut(.return, modifiers: .command)
            #endif
        }
        .animation(
            reduceMotion || appManager.appearance.reduceAnimations ? nil : .spring(response: 0.3, dampingFraction: 0.75),
            value: isSending
        )
        .padding(.trailing, 4)
        .padding(.vertical, 2)
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
                    shape.strokeBorder(.secondary.opacity(0.25), lineWidth: 1)
                }
        } else if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            Color.clear
                .glassEffect(.regular, in: shape)
                .overlay {
                    shape.strokeBorder(.white.opacity(0.12), lineWidth: 0.5)
                }
        } else {
            shape.fill(.regularMaterial)
                .overlay {
                    shape.strokeBorder(.secondary.opacity(0.15), lineWidth: 0.5)
                }
        }
    }
}

private struct ComposerPreview: View {
    @State private var prompt: String
    @FocusState private var isPromptFocused: Bool

    var isEnabled = true
    var isSending = false
    var isStopping = false
    var isLoading = false
    var status = "Prêt"

    init(prompt: String = "", isSending: Bool = false) {
        _prompt = State(initialValue: prompt)
        self.isSending = isSending
    }

    var body: some View {
        ChatInputView(
            prompt: $prompt,
            isEnabled: isEnabled,
            isSending: isSending,
            isStopping: isStopping,
            isLoading: isLoading,
            status: status,
            onSend: {},
            onStop: {},
            focusState: $isPromptFocused
        )
        .environment(AppManager())
        .padding()
    }
}

#Preview("Saisie vide") {
    ComposerPreview()
}

#Preview("En cours de réponse") {
    ComposerPreview(prompt: "Bonjour Noctis", isSending: true)
}
