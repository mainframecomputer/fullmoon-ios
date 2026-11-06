import SwiftData
import SwiftUI
#if os(iOS) || os(visionOS)
import Contacts
#endif

struct NoctisIdentitySettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \NoctisUserProfile.updatedAt, order: .reverse)
    private var profiles: [NoctisUserProfile]

    @State private var displayName = ""
    @State private var preferredName = ""
    @State private var preferredLanguage = "fr"
    @State private var personalInstructions = ""
    @State private var errorMessage: String?
    #if os(iOS) || os(visionOS)
    @State private var showingContactPicker = false
    #endif

    var body: some View {
        Form {
            Section("Identity") {
                TextField("Name", text: $displayName)
                    .textContentType(.name)
                TextField("What should Noctis call you?", text: $preferredName)
                Picker("Language", selection: $preferredLanguage) {
                    Text("Français").tag("fr")
                    Text("English").tag("en")
                }
            }

            #if os(iOS) || os(visionOS)
            Section("Contact") {
                Button("Importer ma fiche contact", systemImage: "person.crop.rectangle") {
                    showingContactPicker = true
                }
                Text("Seuls le nom et le surnom sont copiés dans le formulaire. Vérifiez-les avant de sauvegarder.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            #endif

            Section("Personal preferences") {
                TextEditor(text: $personalInstructions)
                    .frame(minHeight: 90)
                Text("Only information you enter here is saved to your profile.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("iCloud") {
                Label("Cloud synchronization is not enabled yet", systemImage: "icloud.slash")
                Text("Your profile and conversations remain on this device until CloudKit migration is configured.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Button("Save profile") {
                save()
            }
        }
        .navigationTitle("Noctis Identity")
        .onAppear(perform: load)
        #if os(iOS) || os(visionOS)
        .sheet(isPresented: $showingContactPicker) {
            NoctisContactPicker { contact in
                displayName = [contact.givenName, contact.familyName]
                    .filter { !$0.isEmpty }
                    .joined(separator: " ")
                preferredName = contact.nickname
                showingContactPicker = false
            } onCancel: {
                showingContactPicker = false
            }
        }
        #endif
        .alert("Unable to save profile", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func load() {
        guard let profile = profiles.first else { return }
        displayName = profile.displayName
        preferredName = profile.preferredName
        preferredLanguage = profile.preferredLanguage
        personalInstructions = profile.personalInstructions
    }

    private func save() {
        do {
            let profile = try NoctisUserIdentity.getOrCreateProfile(in: modelContext)
            try NoctisUserIdentity.update(
                profile,
                displayName: displayName,
                preferredName: preferredName,
                preferredLanguage: preferredLanguage,
                personalInstructions: personalInstructions,
                in: modelContext
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
