import SwiftUI

enum AppearanceTheme: String, CaseIterable, Codable {
    case system = "Automatique", light = "Clair", dark = "Sombre", midnight = "Noir profond"
    case dusk = "Crépuscule", forest = "Forêt"
    var scheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light, .forest: .light
        case .dark, .midnight, .dusk: .dark
        }
    }
    var background: Color {
        switch self {
        case .midnight: .black
        case .dusk: Color(red: 0.10, green: 0.08, blue: 0.16)
        case .forest: Color(red: 0.94, green: 0.96, blue: 0.93)
        default: DesignTokens.background
        }
    }
}

enum ChatDensity: String, CaseIterable, Codable {
    case compact = "Compacte", standard = "Standard", comfortable = "Confortable"
    var spacing: CGFloat {
        switch self { case .compact: 8; case .standard: 16; case .comfortable: 24 }
    }
}
enum MessageStyle: String, CaseIterable, Codable {
    case bubbles = "Bulles", minimal = "Minimaliste"
}
enum VisualIntensity: String, CaseIterable, Codable {
    case subtle = "Discrète", balanced = "Équilibrée", expressive = "Expressive"
    var opacity: Double {
        switch self { case .subtle: 0.06; case .balanced: 0.12; case .expressive: 0.20 }
    }
}
struct ChatAppearance: Codable, Equatable {
    var theme: AppearanceTheme = .system
    var density: ChatDensity = .standard
    var messageStyle: MessageStyle = .bubbles
    var intensity: VisualIntensity = .balanced
    var fontSize: Double = 16
    var contentWidth: Double = 800
    var showAvatars = true
    var showTimestamps = false
    var reduceAnimations = false
    var useGlass = true
}

enum DesignTokens {
    static let cornerRadius: CGFloat = 20
    static let composerRadius: CGFloat = 26
    static let pageInset: CGFloat = 20
    static var background: Color {
        #if os(macOS)
        Color(nsColor: .windowBackgroundColor)
        #else
        Color(uiColor: .systemBackground)
        #endif
    }
}

struct AppearanceRoot: ViewModifier {
    @Environment(AppManager.self) private var appManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func body(content: Content) -> some View {
        content
            .preferredColorScheme(appManager.appearance.theme.scheme)
            .tint(appManager.appTintColor.getColor())
            .transaction { transaction in
                if reduceMotion || appManager.appearance.reduceAnimations {
                    transaction.animation = nil
                    transaction.disablesAnimations = true
                }
            }
    }
}
