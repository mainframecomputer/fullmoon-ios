import AIEffectsKit
import SwiftUI

struct AppearanceSettingsView: View {
    @Environment(AppManager.self) private var appManager
    @ScaledMetric(relativeTo: .body) private var textScale = 1.0

    var body: some View {
        @Bindable var manager = appManager
        Form {
            Section("Thème et couleurs") {
                Picker("Thème", selection: $manager.appearance.theme) {
                    ForEach(AppearanceTheme.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                Picker("Accentuation", selection: $manager.appTintColor) {
                    ForEach(AppTintColor.allCases, id: \.self) { color in
                        Label(color.rawValue.capitalized, systemImage: "circle.fill").foregroundStyle(color.getColor()).tag(color)
                    }
                }
            }
            Section("Conversations") {
                LabeledContent("Taille du texte", value: "\(Int(manager.appearance.fontSize)) pt")
                Slider(value: $manager.appearance.fontSize, in: 13...24, step: 1) { Text("Taille du texte") }
                Picker("Densité", selection: $manager.appearance.density) {
                    ForEach(ChatDensity.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                Picker("Messages", selection: $manager.appearance.messageStyle) {
                    ForEach(MessageStyle.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                Picker("Largeur de lecture", selection: $manager.appearance.contentWidth) {
                    Text("Étroite").tag(640.0); Text("Standard").tag(800.0); Text("Large").tag(1040.0)
                }
                Toggle("Afficher les avatars", isOn: $manager.appearance.showAvatars)
                Toggle("Afficher les horodatages", isOn: $manager.appearance.showTimestamps)
            }
            Section("Effets visuels") {
                Toggle("Liquid Glass", isOn: $manager.appearance.useGlass)
                Picker("Intensité", selection: $manager.appearance.intensity) {
                    ForEach(VisualIntensity.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                Toggle("Réduire les animations", isOn: $manager.appearance.reduceAnimations)
                Text("Les préférences système de mouvement, transparence et contraste restent prioritaires.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            AIEffectsSettingsSection(appearance: $manager.appearance)
            Section("Aperçu des effets IA") {
                AIEffectsPreview(appearance: manager.appearance, fontSize: manager.appearance.fontSize * textScale)
            }
            Section("Typographie") {
                Picker("Police", selection: $manager.appFontDesign) {
                    ForEach(AppFontDesign.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
                }
                Picker("Chasse", selection: $manager.appFontWidth) {
                    ForEach(AppFontWidth.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
                }.disabled(manager.appFontDesign != .standard)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Apparence et personnalisation")
    }
}

private struct AIEffectsSettingsSection: View {
    @Binding var appearance: ChatAppearance

    var body: some View {
        Section("Effets IA") {
            Toggle("Activer les effets IA", isOn: $appearance.aiEffectsEnabled)
            if appearance.aiEffectsEnabled {
                Picker("Rendu des réponses", selection: $appearance.aiTextRenderingMode) {
                    ForEach(AITextRenderingMode.allCases) { Text($0.title).tag($0) }
                }
                Picker("Animation du texte", selection: $appearance.streamEffect) {
                    ForEach(AIStreamEffect.allCases) { Text($0.title).tag($0) }
                }
                Text(appearance.streamEffect.detail).font(.caption).foregroundStyle(.secondary)
                StreamEffectControls(appearance: $appearance)
                Toggle("Indicateur de réflexion", isOn: $appearance.thinkingIndicatorEnabled)
                if appearance.thinkingIndicatorEnabled {
                    Stepper("Points : \(appearance.thinkingDotCount)", value: $appearance.thinkingDotCount, in: 2...6)
                    ValueSlider(title: "Taille", value: $appearance.thinkingDotSize, range: 3...12, step: 1, suffix: " pt")
                    ValueSlider(title: "Espacement", value: $appearance.thinkingSpacing, range: 1...12, step: 1, suffix: " pt")
                    ValueSlider(title: "Période", value: $appearance.thinkingPeriodMilliseconds, range: 500...2_500, step: 100, suffix: " ms")
                }
                Toggle("Halo d’intelligence", isOn: $appearance.intelligenceGlowEnabled)
                if appearance.intelligenceGlowEnabled {
                    Picker("Palette", selection: $appearance.intelligenceGlowPalette) {
                        ForEach(IntelligenceGlowPalette.allCases) { Text($0.title).tag($0) }
                    }
                    ValueSlider(title: "Épaisseur", value: $appearance.intelligenceGlowLineWidth, range: 0.5...5, step: 0.5, suffix: " pt")
                    ValueSlider(title: "Rayon", value: $appearance.intelligenceGlowCornerRadius, range: 4...36, step: 1, suffix: " pt")
                    Text("Le flou et la vitesse du halo sont calculés par AIEffectsKit et ne sont pas configurables publiquement.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Button("Réinitialiser uniquement les effets", role: .destructive) { appearance.resetEffects() }
        }
    }
}

private struct StreamEffectControls: View {
    @Binding var appearance: ChatAppearance
    var body: some View {
        switch appearance.streamEffect {
        case .none:
            EmptyView()
        case .trailingShimmer:
            Stepper("Fenêtre : \(appearance.shimmerWindow) caractères", value: $appearance.shimmerWindow, in: 2...30)
            ValueSlider(title: "Intensité", value: $appearance.shimmerStrength, range: 0.1...1, step: 0.05)
            ValueSlider(title: "Période", value: $appearance.shimmerPeriodMilliseconds, range: 400...3_000, step: 100, suffix: " ms")
        case .typewriter:
            Toggle("Afficher le curseur", isOn: $appearance.typewriterCaret)
        case .scramble:
            ValueSlider(title: "Intervalle", value: $appearance.scrambleIntervalMilliseconds, range: 15...150, step: 5, suffix: " ms")
            ValueSlider(title: "Probabilité", value: $appearance.scrambleProbability, range: 0.1...1, step: 0.05)
        default:
            ValueSlider(title: "Décalage", value: $appearance.effectStaggerMilliseconds, range: 10...600, step: 5, suffix: " ms")
            ValueSlider(title: appearance.streamEffect == .skeleton ? "Stabilisation" : "Durée",
                        value: $appearance.effectDurationMilliseconds, range: 100...1_500, step: 20, suffix: " ms")
        }
    }
}

private struct ValueSlider: View {
    let title: LocalizedStringKey
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    var suffix = ""

    var body: some View {
        LabeledContent(title, value: "\(Int(value))\(suffix)")
        Slider(value: $value, in: range, step: step) { Text(title) }
    }
}

private struct AIEffectsPreview: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    let appearance: ChatAppearance
    let fontSize: Double
    @State private var state = AIState()
    @State private var phase = AIPhase.idle
    @State private var run = 0
    private let sample = "Une réponse claire, locale et respectueuse de votre rythme."

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if appearance.aiEffectsEnabled && appearance.thinkingIndicatorEnabled && phase == .thinking {
                ThinkingIndicator(dotCount: appearance.thinkingDotCount, dotSize: appearance.thinkingDotSize,
                                  spacing: appearance.thinkingSpacing, period: .milliseconds(appearance.thinkingPeriodMilliseconds))
                    .aiState(state)
            }
            previewText
                .font(.system(size: fontSize))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(.quaternary.opacity(reduceTransparency ? 0.35 : 0.18),
                            in: RoundedRectangle(cornerRadius: appearance.intelligenceGlowCornerRadius))
                .intelligenceGlow(colors: appearance.intelligenceGlowPalette.colors,
                                  lineWidth: appearance.intelligenceGlowLineWidth,
                                  cornerRadius: appearance.intelligenceGlowCornerRadius,
                                  activeWhen: appearance.aiEffectsEnabled && appearance.intelligenceGlowEnabled && phase.isActive)
            HStack {
                Text(phaseLabel).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Rejouer") { run += 1 }.buttonStyle(.bordered).controlSize(.small)
            }
        }
        .task(id: run) { await simulate() }
        .onDisappear { state.phase = .idle; phase = .idle }
    }

    @ViewBuilder private var previewText: some View {
        if phase == .thinking {
            Text("Noctis réfléchit…").foregroundStyle(.secondary)
        } else if appearance.aiEffectsEnabled && appearance.aiTextRenderingMode == .animatedText
                    && appearance.streamEffect != .none && !reduceMotion {
            StreamText.typing(sample, interval: .milliseconds(24), style: appearance.streamTextStyle).id(run)
        } else {
            Text(sample)
        }
    }
    private var phaseLabel: String {
        switch phase { case .idle: "Prêt"; case .thinking: "Réflexion"; case .streaming: "Génération"; case .done: "Terminé"; case .error: "Erreur"; case .listening: "Prêt" }
    }
    private func simulate() async {
        phase = .thinking; state.phase = .thinking
        do {
            try await Task.sleep(for: .milliseconds(750))
            try Task.checkCancellation()
            phase = .streaming; state.phase = .streaming
            try await Task.sleep(for: reduceMotion ? .milliseconds(150) : .milliseconds(1_700))
            try Task.checkCancellation()
            phase = .done; state.phase = .done
        } catch { phase = .idle; state.phase = .idle }
    }
}

#Preview {
    NavigationStack { AppearanceSettingsView() }.environment(AppManager())
}
