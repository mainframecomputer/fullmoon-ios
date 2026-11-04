import SwiftData
import SwiftUI

struct ChatsListView: View {
    @Environment(AppManager.self) private var appManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Binding var currentThread: Thread?
    @FocusState.Binding var isPromptFocused: Bool
    @Query(sort: \Thread.timestamp, order: .reverse) private var threads: [Thread]
    @State private var search = ""
    @State private var deletionError: String?
    @State private var pendingDeletion: Thread?

    private var groups: [ConversationGroup] {
        let matches = threads.filter {
            search.isEmpty || ($0.title?.localizedCaseInsensitiveContains(search) == true)
                || $0.messages.contains { $0.content.localizedCaseInsensitiveContains(search) }
        }
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: .now) ?? .now
        return [
            ConversationGroup(title: "Aujourd’hui", threads: matches.filter { calendar.isDateInToday($0.timestamp) }),
            ConversationGroup(title: "7 derniers jours", threads: matches.filter { !calendar.isDateInToday($0.timestamp) && $0.timestamp >= weekAgo }),
            ConversationGroup(title: "Plus anciennes", threads: matches.filter { $0.timestamp < weekAgo })
        ].filter { !$0.threads.isEmpty }
    }

    var body: some View {
        NavigationStack {
            List(selection: $currentThread) {
                ForEach(groups) { group in
                    Section(group.title) {
                        ForEach(group.threads) { thread in
                            ConversationRow(thread: thread)
                                .tag(thread)
                                .contextMenu {
                                    Button("Supprimer la conversation", role: .destructive) { pendingDeletion = thread }
                                }
                        }
                        .onDelete { offsets in
                            if let first = offsets.first { pendingDeletion = group.threads[first] }
                        }
                    }
                }
            }
            .overlay {
                if groups.isEmpty {
                    ContentUnavailableView(search.isEmpty ? "Votre espace de réflexion" : "Aucun résultat",
                                           systemImage: search.isEmpty ? "moon.stars" : "magnifyingglass",
                                           description: Text(search.isEmpty ? "Vos conversations apparaîtront ici." : "Essayez d’autres mots."))
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("Fullmoon")
            .searchable(text: $search, prompt: "Rechercher dans l’historique")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        currentThread = nil
                        isPromptFocused = true
                        if appManager.userInterfaceIdiom == .phone { dismiss() }
                    } label: {
                        Label("Nouvelle conversation", systemImage: "square.and.pencil")
                    }
                    .keyboardShortcut("n", modifiers: .command)
                }
            }
            .onChange(of: currentThread) {
                isPromptFocused = true
                if appManager.userInterfaceIdiom == .phone { dismiss() }
            }
            .confirmationDialog("Supprimer cette conversation ?", isPresented: Binding(
                get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } }
            ), titleVisibility: .visible) {
                Button("Supprimer", role: .destructive) {
                    guard let thread = pendingDeletion else { return }
                    if currentThread?.id == thread.id { currentThread = nil }
                    for message in thread.messages { modelContext.delete(message) }
                    modelContext.delete(thread)
                    do { try modelContext.save() }
                    catch { deletionError = error.localizedDescription }
                    pendingDeletion = nil
                }
            }
            .alert("Suppression impossible", isPresented: Binding(
                get: { deletionError != nil }, set: { if !$0 { deletionError = nil } }
            )) {
                Button("OK") { deletionError = nil }
            } message: { Text(deletionError ?? "") }
        }
    }
}

private struct ConversationGroup: Identifiable {
    let title: String
    let threads: [Thread]
    var id: String { title }
}

private struct ConversationRow: View {
    let thread: Thread
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "bubble.left").foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 5) {
                Text(thread.title ?? thread.sortedMessages.first?.content ?? "Nouvelle conversation")
                    .font(.body.weight(.medium)).lineLimit(1)
                Text(thread.timestamp, format: .dateTime.day().month().hour().minute())
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(.vertical, 5)
        }
        .accessibilityElement(children: .combine)
    }
}
