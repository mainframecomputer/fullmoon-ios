import SwiftUI

/// Local preference only. Cloud synchronization is deliberately not enabled until
/// the existing SwiftData store has a verified, lossless CloudKit migration.
struct NoctisPrivacySettingsView: View {
    @AppStorage("noctis.lock.enabled") private var lockEnabled = false
    @AppStorage("noctis.icloud.requested") private var iCloudRequested = false
    @State private var errorMessage: String?
    @State private var showingCloudExplanation = false
    @State private var showingDisableConfirmation = false

    var body: some View {
        Form {
            Section("Sécurité") {
                Toggle("Verrouiller Noctis", isOn: Binding(
                    get: { lockEnabled },
                    set: { enabled in
                        if !enabled {
                            showingDisableConfirmation = true
                        } else {
                            Task {
                                do {
                                    try await NoctisDeviceAuthenticator().unlock(
                                        reason: "Activer le verrouillage de Noctis"
                                    )
                                    lockEnabled = true
                                } catch {
                                    errorMessage = error.localizedDescription
                                }
                            }
                        }
                    }
                ))
                Text("Face ID, Touch ID ou code de l’appareil selon la disponibilité.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Synchronisation iCloud") {
                Toggle("Synchroniser avec iCloud", isOn: Binding(
                    get: { iCloudRequested },
                    set: { enabled in
                        if enabled {
                            showingCloudExplanation = true
                        } else {
                            iCloudRequested = false
                        }
                    }
                ))
                .disabled(true)
                Label("Non disponible dans cette version", systemImage: "icloud.slash")
                    .foregroundStyle(.secondary)
                Text("Les données restent locales. La synchronisation sera proposée après validation de la migration CloudKit et des règles de suppression.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Confidentialité")
        .confirmationDialog("Désactiver le verrouillage ?", isPresented: $showingDisableConfirmation) {
            Button("Confirmer avec Face ID ou le code") {
                Task {
                    do {
                        try await NoctisDeviceAuthenticator().unlock(reason: "Désactiver le verrouillage Noctis")
                        lockEnabled = false
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
            }
        }
        .alert("Authentification impossible", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .alert("iCloud indisponible", isPresented: $showingCloudExplanation) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("La synchronisation n'est pas encore activée. Aucune donnée n'est envoyée.")
        }
    }
}
