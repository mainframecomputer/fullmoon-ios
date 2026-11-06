import AIEffectsKit
import SwiftUI

enum AppearanceTheme: String, CaseIterable, Codable {
    case system = "Automatique", light = "Clair", dark = "Sombre", midnight = "Noir profond"
    case dusk = "Crépuscule", forest = "Forêt"
    var scheme: ColorScheme? { switch self { case .system: nil; case .light, .forest: .light; case .dark, .midnight, .dusk: .dark } }
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
    var spacing: CGFloat { switch self { case .compact: 8; case .standard: 16; case .comfortable: 24 } }
}
enum MessageStyle: String, CaseIterable, Codable { case bubbles = "Bulles", minimal = "Minimaliste" }
enum VisualIntensity: String, CaseIterable, Codable {
    case subtle = "Discrète", balanced = "Équilibrée", expressive = "Expressive"
    var opacity: Double { switch self { case .subtle: 0.06; case .balanced: 0.12; case .expressive: 0.20 } }
}

enum AITextRenderingMode: String, CaseIterable, Codable, Identifiable {
    case markdown, animatedText
    var id: Self { self }
    var title: String { self == .markdown ? "Markdown" : "Texte animé" }
}

enum AIStreamEffect: String, CaseIterable, Codable, Identifiable {
    case none, trailingShimmer, typewriter, wordReveal, tokenChunks, fadeRise, blurFocus
    case shimmerWipe, skeleton, scramble, letterDrop, lineCascade
    var id: Self { self }
    var title: String {
        switch self {
        case .none: "Aucun effet"; case .trailingShimmer: "Scintillement final"; case .typewriter: "Machine à écrire"
        case .wordReveal: "Révélation par mots"; case .tokenChunks: "Fragments successifs"; case .fadeRise: "Fondu ascendant"
        case .blurFocus: "Mise au point"; case .shimmerWipe: "Balayage lumineux"; case .skeleton: "Squelette"
        case .scramble: "Brouillage"; case .letterDrop: "Chute de lettres"; case .lineCascade: "Cascade de lignes"
        }
    }
    var detail: String {
        switch self {
        case .none: "Affiche immédiatement le texte reçu."
        case .trailingShimmer: "Une lueur discrète suit les derniers caractères."
        case .typewriter: "Le texte progresse avec un curseur optionnel."
        case .wordReveal: "Les mots apparaissent progressivement."
        case .tokenChunks: "Les fragments se fondent par petits groupes."
        case .fadeRise: "Chaque mot monte doucement en apparaissant."
        case .blurFocus: "Les mots passent du flou à la netteté."
        case .shimmerWipe: "Une lumière révèle chaque mot."
        case .skeleton: "Un espace réservé précède brièvement le texte."
        case .scramble: "Les caractères se stabilisent depuis un brouillage."
        case .letterDrop: "Les lettres se déposent en place."
        case .lineCascade: "Les lignes arrivent en cascade."
        }
    }
}

enum IntelligenceGlowPalette: String, CaseIterable, Codable, Identifiable {
    case noctis, ocean, sunset, monochrome
    var id: Self { self }
    var title: String { switch self { case .noctis: "Noctis"; case .ocean: "Océan"; case .sunset: "Crépuscule"; case .monochrome: "Monochrome" } }
    var colors: [Color] {
        switch self {
        case .noctis: [.indigo, .purple, .pink, .indigo]
        case .ocean: [.blue, .cyan, .mint, .blue]
        case .sunset: [.orange, .pink, .red, .orange]
        case .monochrome: [.secondary.opacity(0.35), .primary, .secondary.opacity(0.35), .primary]
        }
    }
}

struct ChatAppearance: Codable, Equatable {
    var theme: AppearanceTheme = .system
    var density: ChatDensity = .standard
    var messageStyle: MessageStyle = .bubbles
    var intensity: VisualIntensity = .balanced
    var fontSize = 16.0
    var contentWidth = 800.0
    var showAvatars = true
    var showTimestamps = false
    var reduceAnimations = false
    var useGlass = true
    var aiEffectsEnabled = false
    var aiTextRenderingMode: AITextRenderingMode = .markdown
    var streamEffect: AIStreamEffect = .none
    var effectStaggerMilliseconds = 55.0
    var effectDurationMilliseconds = 260.0
    var shimmerWindow = 10
    var shimmerStrength = 0.45
    var shimmerPeriodMilliseconds = 1_200.0
    var typewriterCaret = true
    var scrambleIntervalMilliseconds = 40.0
    var scrambleProbability = 0.55
    var thinkingIndicatorEnabled = true
    var thinkingDotCount = 3
    var thinkingDotSize = 6.0
    var thinkingSpacing = 4.0
    var thinkingPeriodMilliseconds = 1_100.0
    var intelligenceGlowEnabled = false
    var intelligenceGlowPalette: IntelligenceGlowPalette = .noctis
    var intelligenceGlowLineWidth = 1.5
    var intelligenceGlowCornerRadius = 20.0

    mutating func resetEffects() {
        let value = Self()
        aiEffectsEnabled = value.aiEffectsEnabled; aiTextRenderingMode = value.aiTextRenderingMode; streamEffect = value.streamEffect
        effectStaggerMilliseconds = value.effectStaggerMilliseconds; effectDurationMilliseconds = value.effectDurationMilliseconds
        shimmerWindow = value.shimmerWindow; shimmerStrength = value.shimmerStrength; shimmerPeriodMilliseconds = value.shimmerPeriodMilliseconds
        typewriterCaret = value.typewriterCaret; scrambleIntervalMilliseconds = value.scrambleIntervalMilliseconds
        scrambleProbability = value.scrambleProbability; thinkingIndicatorEnabled = value.thinkingIndicatorEnabled
        thinkingDotCount = value.thinkingDotCount; thinkingDotSize = value.thinkingDotSize; thinkingSpacing = value.thinkingSpacing
        thinkingPeriodMilliseconds = value.thinkingPeriodMilliseconds; intelligenceGlowEnabled = value.intelligenceGlowEnabled
        intelligenceGlowPalette = value.intelligenceGlowPalette; intelligenceGlowLineWidth = value.intelligenceGlowLineWidth
        intelligenceGlowCornerRadius = value.intelligenceGlowCornerRadius
    }

    var streamTextStyle: StreamTextStyle {
        let stagger = Duration.milliseconds(effectStaggerMilliseconds)
        let duration = Duration.milliseconds(effectDurationMilliseconds)
        switch streamEffect {
        case .none, .trailingShimmer:
            return StreamTextStyle.trailingShimmer(
                window: shimmerWindow,
                strength: shimmerStrength,
                period: .milliseconds(shimmerPeriodMilliseconds)
            )
        case .typewriter:
            return StreamTextStyle.typewriter(caret: typewriterCaret)
        case .wordReveal:
            return StreamTextStyle.wordReveal(stagger: stagger, duration: duration)
        case .tokenChunks:
            return StreamTextStyle.tokenChunks(stagger: stagger, duration: duration)
        case .fadeRise:
            return StreamTextStyle.fadeRise(stagger: stagger, duration: duration)
        case .blurFocus:
            return StreamTextStyle.blurFocus(stagger: stagger, duration: duration)
        case .shimmerWipe:
            return StreamTextStyle.shimmerWipe(stagger: stagger, duration: duration)
        case .skeleton:
            return StreamTextStyle.skeleton(stagger: stagger, settleDuration: duration)
        case .scramble:
            return StreamTextStyle.scramble(
                advanceInterval: .milliseconds(scrambleIntervalMilliseconds),
                advanceProbability: scrambleProbability
            )
        case .letterDrop:
            return StreamTextStyle.letterDrop(stagger: stagger, duration: duration)
        case .lineCascade:
            return StreamTextStyle.lineCascade(stagger: stagger, duration: duration)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case theme, density, messageStyle, intensity, fontSize, contentWidth, showAvatars, showTimestamps, reduceAnimations, useGlass
        case aiEffectsEnabled, aiTextRenderingMode, streamEffect, effectStaggerMilliseconds, effectDurationMilliseconds
        case shimmerWindow, shimmerStrength, shimmerPeriodMilliseconds, typewriterCaret, scrambleIntervalMilliseconds, scrambleProbability
        case thinkingIndicatorEnabled, thinkingDotCount, thinkingDotSize, thinkingSpacing, thinkingPeriodMilliseconds
        case intelligenceGlowEnabled, intelligenceGlowPalette, intelligenceGlowLineWidth, intelligenceGlowCornerRadius
    }
    init() {}
    init(from decoder: Decoder) throws {
        self.init()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        theme = try c.decodeIfPresent(AppearanceTheme.self, forKey: .theme) ?? theme
        density = try c.decodeIfPresent(ChatDensity.self, forKey: .density) ?? density
        messageStyle = try c.decodeIfPresent(MessageStyle.self, forKey: .messageStyle) ?? messageStyle
        intensity = try c.decodeIfPresent(VisualIntensity.self, forKey: .intensity) ?? intensity
        fontSize = try c.decodeIfPresent(Double.self, forKey: .fontSize) ?? fontSize
        contentWidth = try c.decodeIfPresent(Double.self, forKey: .contentWidth) ?? contentWidth
        showAvatars = try c.decodeIfPresent(Bool.self, forKey: .showAvatars) ?? showAvatars
        showTimestamps = try c.decodeIfPresent(Bool.self, forKey: .showTimestamps) ?? showTimestamps
        reduceAnimations = try c.decodeIfPresent(Bool.self, forKey: .reduceAnimations) ?? reduceAnimations
        useGlass = try c.decodeIfPresent(Bool.self, forKey: .useGlass) ?? useGlass
        aiEffectsEnabled = try c.decodeIfPresent(Bool.self, forKey: .aiEffectsEnabled) ?? aiEffectsEnabled
        aiTextRenderingMode = try c.decodeIfPresent(AITextRenderingMode.self, forKey: .aiTextRenderingMode) ?? aiTextRenderingMode
        streamEffect = try c.decodeIfPresent(AIStreamEffect.self, forKey: .streamEffect) ?? streamEffect
        effectStaggerMilliseconds = try c.decodeIfPresent(Double.self, forKey: .effectStaggerMilliseconds) ?? effectStaggerMilliseconds
        effectDurationMilliseconds = try c.decodeIfPresent(Double.self, forKey: .effectDurationMilliseconds) ?? effectDurationMilliseconds
        shimmerWindow = try c.decodeIfPresent(Int.self, forKey: .shimmerWindow) ?? shimmerWindow
        shimmerStrength = try c.decodeIfPresent(Double.self, forKey: .shimmerStrength) ?? shimmerStrength
        shimmerPeriodMilliseconds = try c.decodeIfPresent(Double.self, forKey: .shimmerPeriodMilliseconds) ?? shimmerPeriodMilliseconds
        typewriterCaret = try c.decodeIfPresent(Bool.self, forKey: .typewriterCaret) ?? typewriterCaret
        scrambleIntervalMilliseconds = try c.decodeIfPresent(Double.self, forKey: .scrambleIntervalMilliseconds) ?? scrambleIntervalMilliseconds
        scrambleProbability = try c.decodeIfPresent(Double.self, forKey: .scrambleProbability) ?? scrambleProbability
        thinkingIndicatorEnabled = try c.decodeIfPresent(Bool.self, forKey: .thinkingIndicatorEnabled) ?? thinkingIndicatorEnabled
        thinkingDotCount = try c.decodeIfPresent(Int.self, forKey: .thinkingDotCount) ?? thinkingDotCount
        thinkingDotSize = try c.decodeIfPresent(Double.self, forKey: .thinkingDotSize) ?? thinkingDotSize
        thinkingSpacing = try c.decodeIfPresent(Double.self, forKey: .thinkingSpacing) ?? thinkingSpacing
        thinkingPeriodMilliseconds = try c.decodeIfPresent(Double.self, forKey: .thinkingPeriodMilliseconds) ?? thinkingPeriodMilliseconds
        intelligenceGlowEnabled = try c.decodeIfPresent(Bool.self, forKey: .intelligenceGlowEnabled) ?? intelligenceGlowEnabled
        intelligenceGlowPalette = try c.decodeIfPresent(IntelligenceGlowPalette.self, forKey: .intelligenceGlowPalette) ?? intelligenceGlowPalette
        intelligenceGlowLineWidth = try c.decodeIfPresent(Double.self, forKey: .intelligenceGlowLineWidth) ?? intelligenceGlowLineWidth
        intelligenceGlowCornerRadius = try c.decodeIfPresent(Double.self, forKey: .intelligenceGlowCornerRadius) ?? intelligenceGlowCornerRadius
    }
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
        content.preferredColorScheme(appManager.appearance.theme.scheme).tint(appManager.appTintColor.getColor())
            .transaction { transaction in
                if reduceMotion || appManager.appearance.reduceAnimations { transaction.animation = nil; transaction.disablesAnimations = true }
            }
    }
}
