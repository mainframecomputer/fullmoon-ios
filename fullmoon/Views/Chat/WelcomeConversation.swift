import SwiftUI

struct WelcomeConversation: View {
    let onSelect: (String) -> Void
    private let suggestions = [
        "Aide-moi à clarifier une idée.",
        "Explique-moi un concept simplement.",
        "Propose un plan pour mon prochain projet."
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(systemName: "moon.stars")
                    .font(.system(size: 42, weight: .light))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                Text("Un espace pour vos idées")
                    .font(.title2.weight(.semibold))
                Text("Écrivez, explorez, prenez du recul.\nFullmoon réfléchit avec vous, sur cet appareil.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                VStack(spacing: 10) {
                    ForEach(suggestions, id: \.self) { suggestion in
                        Button { onSelect(suggestion) } label: {
                            HStack {
                                Text(suggestion).multilineTextAlignment(.leading)
                                Spacer()
                                Image(systemName: "arrow.up.left")
                            }
                            .padding(12)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .frame(maxWidth: 400)
            }
            .padding(32)
            .frame(maxWidth: .infinity)
        }
        .defaultScrollAnchor(.top)
    }
}

#Preview { WelcomeConversation { _ in } }
