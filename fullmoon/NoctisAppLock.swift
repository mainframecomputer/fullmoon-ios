import SwiftUI

struct NoctisAppLock: ViewModifier {
    @AppStorage("noctis.lock.enabled") private var lockEnabled = false
    @Environment(\.scenePhase) private var scenePhase
    @State private var unlocked = false
    @State private var authenticating = false
    @State private var errorMessage: String?

    func body(content: Content) -> some View {
        ZStack {
            if !lockEnabled || unlocked {
                content
            } else {
                VStack(spacing: 18) {
                    Image(systemName: "lock.shield")
                        .font(.system(size: 42))
                    Text("Noctis est verrouillé")
                        .font(.title2.bold())
                    Button("Déverrouiller") {
                        Task { await authenticate() }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(authenticating)
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.regularMaterial)
            }
        }
        .task(id: lockEnabled) {
            if lockEnabled {
                unlocked = false
                await authenticate()
            } else {
                unlocked = true
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase != .active && lockEnabled {
                unlocked = false
            } else if newPhase == .active && lockEnabled {
                Task { await authenticate() }
            }
        }
    }

    @MainActor
    private func authenticate() async {
        guard lockEnabled, !unlocked, !authenticating else { return }
        authenticating = true
        defer { authenticating = false }
        do {
            try await NoctisDeviceAuthenticator().unlock()
            unlocked = true
            errorMessage = nil
        } catch {
            unlocked = false
            errorMessage = error.localizedDescription
        }
    }
}

extension View {
    func noctisAppLock() -> some View {
        modifier(NoctisAppLock())
    }
}
