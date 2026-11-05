import MarkdownUI
import SwiftUI

struct MessageCodeBlock: View {
    @Environment(AppManager.self) private var appManager
    let configuration: CodeBlockConfiguration
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "curlybraces")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(configuration.language?.uppercased() ?? "CODE")
                        .font(.caption2.weight(.semibold).monospaced())
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Button {
                    #if os(macOS)
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(configuration.content, forType: .string)
                    #else
                    UIPasteboard.general.string = configuration.content
                    #endif
                    appManager.playHaptic()
                    copied = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        Text(copied ? "Copié" : "Copier")
                    }
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(copied ? Color.green : Color.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.quaternary.opacity(0.4), in: Capsule())
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
                .accessibilityLabel(copied ? "Code copié" : "Copier le bloc de code")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.quaternary.opacity(0.25))

            Divider()

            ScrollView(.horizontal, showsIndicators: true) {
                configuration.label
                    .markdownTextStyle {
                        FontFamilyVariant(.monospaced)
                        FontSize(.em(0.88))
                    }
                    .padding(12)
            }
        }
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.quaternary.opacity(0.18))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.secondary.opacity(0.2), lineWidth: 0.5)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onChange(of: configuration.content) {
            copied = false
        }
    }
}
