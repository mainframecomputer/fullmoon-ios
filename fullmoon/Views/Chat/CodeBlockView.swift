import SwiftUI
import MarkdownUI
import Highlightr

private let languageMap: [String: String] = [
    "js": "javascript",
    "ts": "typescript",
    "py": "python",
    "rb": "ruby",
    "shell": "bash",
    "sh": "bash",
    "swift: "swift",
    "jsx": "javascript",
    "tsx": "typescript",
    "yml": "yaml",
    "md": "markdown",
    "cpp": "c++",
    "objective-c": "objectivec",
    "objc": "objectivec",
    "golang": "go"
]

struct CodeBlockView: View {
    let code: String
    let language: String?
    @Environment(\.colorScheme) var colorScheme
    @State private var isCopied = false
    
    private let highlightr = Highlightr()
    
    var platformBackgroundColor: Color {
        #if os(iOS)
        return Color(UIColor.secondarySystemBackground)
        #elseif os(visionOS)
        return Color(UIColor.separator)
        #elseif os(macOS)
        return Color(NSColor.secondarySystemFill)
        #endif
    }
    
    private func normalizeLanguage(_ language: String?) -> String? {
        guard let language = language?.lowercased() else { return nil }
        return languageMap[language] ?? language
    }
    
    var highlightedCode: NSAttributedString? {
        guard let highlightr = highlightr else { return nil }
        highlightr.setTheme(to: colorScheme == .dark ? "atom-one-dark" : "atom-one-light")
        highlightr.theme.codeFont = .monospacedSystemFont(ofSize: 14, weight: .regular)
        return highlightr.highlight(code, as: normalizeLanguage(language))
    }
    
    func copyToClipboard() {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(code, forType: .string)
        #else
        UIPasteboard.general.string = code
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        #endif
        
        withAnimation {
            isCopied = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                isCopied = false
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                if let language {
                    Text(language)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: copyToClipboard) {
                    HStack(spacing: 4) {
                        Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 12))
                        Text(isCopied ? "Copied!" : "Copy")
                            .font(.caption)
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(.secondary.opacity(0.1))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 2)
            
            ScrollView(.horizontal, showsIndicators: false) {
                if let highlightedCode {
                    Text(AttributedString(highlightedCode))
                        .textSelection(.enabled)
                } else {
                    Text(code)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                }
            }
        }
        .padding()
        .background(platformBackgroundColor)
        .cornerRadius(8)
    }
}

#Preview {
    VStack(spacing: 20) {
        CodeBlockView(
            code: "print(\"Hello, World!\")",
            language: "swift"
        )
        CodeBlockView(
            code: "function hello() {\n  console.log('Hello World');\n}",
            language: "js"
        )
        CodeBlockView(
            code: "def hello():\n    print('Hello World')",
            language: "python"
        )
    }
    .padding()
}
