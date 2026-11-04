import MarkdownUI
import SwiftUI

struct MessageView: View {
    @Environment(AppManager.self) private var appManager
    @ScaledMetric(relativeTo: .body) private var textScale = 1.0
    let message: Message
    var onRegenerate: (() -> Void)? = nil
    @State private var copied = false

    var body: some View {
        let appearance = appManager.appearance
        let isUser = message.role == .user
        HStack(alignment: .top, spacing: 10) {
            if isUser { Spacer(minLength: 24) }
            if appearance.showAvatars && !isUser {
                Image(systemName: "moon.stars.fill")
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(isUser ? "Vous" : "Fullmoon").font(.caption.weight(.semibold))
                    if appearance.showTimestamps {
                        Text(message.timestamp, style: .time).font(.caption)
                    }
                }
                .foregroundStyle(.secondary)
                Markdown(message.content)
                    .markdownTextStyle {
                        FontSize(appearance.fontSize * textScale)
                    }
                    .markdownBlockStyle(\.codeBlock) { configuration in
                        MessageCodeBlock(configuration: configuration)
                    }
                    .textSelection(.enabled)
                HStack(spacing: 16) {
                    Button {
                        #if os(macOS)
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(message.content, forType: .string)
                        #else
                        UIPasteboard.general.string = message.content
                        #endif
                        copied = true
                    } label: {
                        Label(copied ? "Copié" : "Copier", systemImage: copied ? "checkmark" : "doc.on.doc")
                    }
                    if let onRegenerate {
                        Button(action: onRegenerate) {
                            Label("Régénérer", systemImage: "arrow.clockwise")
                        }
                    }
                    ShareLink(item: message.content) {
                        Label("Partager", systemImage: "square.and.arrow.up")
                    }
                }
                .font(.caption)
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .onChange(of: message.content) { copied = false }
            }
            .padding(appearance.messageStyle == .bubbles ? 16 : 4)
            .background {
                if appearance.messageStyle == .bubbles {
                    RoundedRectangle(cornerRadius: DesignTokens.cornerRadius)
                        .fill(isUser ? appManager.appTintColor.getColor().opacity(appearance.intensity.opacity) : Color.primary.opacity(0.035))
                }
            }
            if !isUser { Spacer(minLength: 0) }
        }
    }
}
