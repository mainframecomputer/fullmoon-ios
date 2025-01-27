import SwiftUI
import MarkdownUI
import Highlightr

struct CodeBlockView: View {
    let code: String
    let language: String?
    @Environment(\.colorScheme) var colorScheme
    
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
    
    var highlightedCode: NSAttributedString? {
        guard let highlightr = highlightr else { return nil }
        highlightr.setTheme(to: colorScheme == .dark ? "atom-one-dark" : "atom-one-light")
        highlightr.theme.codeFont = .monospacedSystemFont(ofSize: 14, weight: .regular)
        return highlightr.highlight(code, as: language)
    }
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 4) {
                if let language {
                    Text(language)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 2)
                }
                
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
    VStack {
        CodeBlockView(
            code: "print(\"Hello, World!\")",
            language: "swift"
        )
        CodeBlockView(
            code: "function hello() {\n  console.log('Hello World');\n}",
            language: "javascript"
        )
    }
    .padding()
}