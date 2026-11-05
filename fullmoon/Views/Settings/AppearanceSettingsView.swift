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
                        Label(color.rawValue.capitalized, systemImage: "circle.fill")
                            .foregroundStyle(color.getColor()).tag(color)
                    }
                }
            }
            Section("Conversations") {
                LabeledContent("Taille du texte", value: "\(Int(manager.appearance.fontSize)) pt")
                Slider(value: $manager.appearance.fontSize, in: 13...24, step: 1) {
                    Text("Taille du texte")
                }
                Picker("Densité", selection: $manager.appearance.density) {
                    ForEach(ChatDensity.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                Picker("Messages", selection: $manager.appearance.messageStyle) {
                    ForEach(MessageStyle.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                Picker("Largeur de lecture", selection: $manager.appearance.contentWidth) {
                    Text("Étroite").tag(640.0)
                    Text("Standard").tag(800.0)
                    Text("Large").tag(1040.0)
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
                Text("Les préférences système de mouvement, transparence et contraste restent prioritaires. Le verre natif nécessite un système 26 ou ultérieur.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Typographie") {
                Picker("Police", selection: $manager.appFontDesign) {
                    ForEach(AppFontDesign.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
                }
                Picker("Chasse", selection: $manager.appFontWidth) {
                    ForEach(AppFontWidth.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
                }
                .disabled(manager.appFontDesign != .standard)
            }
            Section("Aperçu") {
                Text("Un peu de calme pour vos grandes idées.")
                    .font(.system(size: manager.appearance.fontSize * textScale))
                    .padding()
                    .background(manager.appTintColor.getColor().opacity(manager.appearance.intensity.opacity),
                                in: RoundedRectangle(cornerRadius: DesignTokens.cornerRadius))
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Apparence et personnalisation")
    }
}

#Preview {
    NavigationStack { AppearanceSettingsView() }.environment(AppManager())
}
