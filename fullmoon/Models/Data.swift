//
//  Data.swift
//  fullmoon
//
//  Created by Jordan Singer on 10/5/24.
//

import SwiftUI
import SwiftData

class AppManager: ObservableObject {
    @AppStorage("systemPrompt") var systemPrompt = "you are a helpful assistant"
    @AppStorage("appTintColor") var appTintColor: AppTintColor = .monochrome
    @AppStorage("appFontDesign") var appFontDesign: AppFontDesign = .standard
    @AppStorage("appFontSize") var appFontSize: AppFontSize = .medium
    @AppStorage("appFontWidth") var appFontWidth: AppFontWidth = .standard
    @AppStorage("currentModelName") var currentModelName: String?
    @AppStorage("shouldPlayHaptics") var shouldPlayHaptics = true
    @AppStorage("numberOfVisits") var numberOfVisits = 0
    @AppStorage("numberOfVisitsOfLastRequest") var numberOfVisitsOfLastRequest = 0
    @AppStorage("isUsingServer") var isUsingServer = false
    @AppStorage("serverAPIKey") var serverAPIKeyStorage = ""
    @AppStorage("selectedServerId") var selectedServerIdString: String?
    
    @Published var servers: [ServerConfig] = []
    @Published var selectedServerId: UUID? {
        didSet {
            selectedServerIdString = selectedServerId?.uuidString
            // Reset current model when switching servers
            currentModelName = nil
        }
    }
    
    private let serversKey = "savedServers"
    
    var currentServerURL: String {
        if let server = currentServer {
            return server.url
        }
        return ""
    }
    
    var currentServerAPIKey: String {
        if let server = currentServer {
            return server.apiKey
        }
        return serverAPIKeyStorage
    }
    
    var currentServer: ServerConfig? {
        guard let id = selectedServerId else { return nil }
        return servers.first { $0.id == id }
    }
    
    var userInterfaceIdiom: LayoutType {
        #if os(visionOS)
        return .vision
        #elseif os(macOS)
        return .mac
        #elseif os(iOS)
        return UIDevice.current.userInterfaceIdiom == .pad ? .pad : .phone
        #else
        return .unknown
        #endif
    }

    enum LayoutType {
        case mac, phone, pad, vision, unknown
    }
        
    private let installedModelsKey = "installedModels"
        
    @Published var installedModels: [String] = [] {
        didSet {
            saveInstalledModelsToUserDefaults()
        }
    }
    
    // Add a dictionary to cache models for each server
    @AppStorage("cachedServerModels") private var cachedServerModelsData: Data?
    @Published private(set) var cachedServerModels: [UUID: [String]] = [:] {
        didSet {
            // Save to UserDefaults whenever cache updates
            if let encoded = try? JSONEncoder().encode(cachedServerModels) {
                cachedServerModelsData = encoded
            }
        }
    }
    
    init() {
        // First load saved servers
        loadServers()
        
        // Then restore selected server from saved ID string
        if let savedIdString = selectedServerIdString,
           let savedId = UUID(uuidString: savedIdString) {
            selectedServerId = savedId
        }
        
        // If we have servers but no selection, select the first one
        if selectedServerId == nil && !servers.isEmpty {
            selectedServerId = servers.first?.id
        }
        
        // Finally load cached models
        loadCachedModels()
        loadInstalledModelsFromUserDefaults()
    }
    
    func incrementNumberOfVisits() {
        numberOfVisits += 1
        print("app visits: \(numberOfVisits)")
    }
    
    // Function to save the array to UserDefaults as JSON
    private func saveInstalledModelsToUserDefaults() {
        if let jsonData = try? JSONEncoder().encode(installedModels) {
            UserDefaults.standard.set(jsonData, forKey: installedModelsKey)
        }
    }
    
    // Function to load the array from UserDefaults
    private func loadInstalledModelsFromUserDefaults() {
        if let jsonData = UserDefaults.standard.data(forKey: installedModelsKey),
           let decodedArray = try? JSONDecoder().decode([String].self, from: jsonData) {
            self.installedModels = decodedArray
        } else {
            self.installedModels = [] // Default to an empty array if there's no data
        }
    }
    
    func playHaptic() {
        if shouldPlayHaptics {
            #if os(iOS)
            let impact = UIImpactFeedbackGenerator(style: .soft)
            impact.impactOccurred()
            #endif
        }
    }
    
    func addInstalledModel(_ model: String) {
        if !installedModels.contains(model) {
            installedModels.append(model)
        }
    }
    
    func modelDisplayName(_ modelName: String) -> String {
        return modelName.replacingOccurrences(of: "mlx-community/", with: "").lowercased()
    }
    
    func getMoonPhaseIcon() -> String {
        // Get current date
        let currentDate = Date()
        
        // Define a base date (known new moon date)
        let baseDate = Calendar.current.date(from: DateComponents(year: 2000, month: 1, day: 6))!
        
        // Difference in days between the current date and the base date
        let daysSinceBaseDate = Calendar.current.dateComponents([.day], from: baseDate, to: currentDate).day!
        
        // Moon phase repeats approximately every 29.53 days
        let moonCycleLength = 29.53
        let daysIntoCycle = Double(daysSinceBaseDate).truncatingRemainder(dividingBy: moonCycleLength)
        
        // Determine the phase based on how far into the cycle we are
        switch daysIntoCycle {
        case 0..<1.8457:
            return "moonphase.new.moon" // New Moon
        case 1.8457..<5.536:
            return "moonphase.waxing.crescent" // Waxing Crescent
        case 5.536..<9.228:
            return "moonphase.first.quarter" // First Quarter
        case 9.228..<12.919:
            return "moonphase.waxing.gibbous" // Waxing Gibbous
        case 12.919..<16.610:
            return "moonphase.full.moon" // Full Moon
        case 16.610..<20.302:
            return "moonphase.waning.gibbous" // Waning Gibbous
        case 20.302..<23.993:
            return "moonphase.last.quarter" // Last Quarter
        case 23.993..<27.684:
            return "moonphase.waning.crescent" // Waning Crescent
        default:
            return "moonphase.new.moon" // New Moon (fallback)
        }
    }
    
    func modelSource() -> ModelSource {
        isUsingServer ? .server : .local
    }
    
    private func loadServers() {
        if let data = UserDefaults.standard.data(forKey: serversKey),
           let decodedServers = try? JSONDecoder().decode([ServerConfig].self, from: data) {
            servers = decodedServers
        }
    }
    
    func saveServers() {
        if let encoded = try? JSONEncoder().encode(servers) {
            UserDefaults.standard.set(encoded, forKey: serversKey)
        }
    }
    
    // Update server saving to happen immediately when servers change
    func addServer(_ server: ServerConfig) {
        servers.append(server)
        saveServers()
        
        // Auto-select the first server if none is selected
        if selectedServerId == nil {
            selectedServerId = server.id
        }
    }
    
    func removeServer(_ server: ServerConfig) {
        servers.removeAll { $0.id == server.id }
        saveServers()
        
        // Clear selection if removed server was selected
        if selectedServerId == server.id {
            selectedServerId = servers.first?.id
        }
    }
    
    func updateServer(_ server: ServerConfig) {
        if let index = servers.firstIndex(where: { $0.id == server.id }) {
            servers[index] = server
            saveServers()
        }
    }
    
    func addServerWithMetadata(_ server: ServerConfig) async {
        var updatedServer = server
        
        // Try to fetch server metadata
        let metadata = await fetchServerMetadata(url: server.url)
        if let title = metadata.title {
            updatedServer.name = title
        }
        
        await MainActor.run {
            addServer(updatedServer)
            selectedServerId = updatedServer.id
        }
    }
    
    private func fetchServerMetadata(url: String) async -> (title: String?, version: String?) {
        guard var baseURL = URL(string: url) else { return (nil, nil) }
        // Remove /v1 or other API paths to get base URL
        baseURL = baseURL.deletingLastPathComponent()
        
        do {
            let (data, _) = try await URLSession.shared.data(from: baseURL)
            if let html = String(data: data, encoding: .utf8) {
                // Extract title from HTML metadata
                let title = extractTitle(from: html)
                let version = extractVersion(from: html)
                return (title, version)
            }
        } catch {
            print("Error fetching server metadata: \(error)")
        }
        return (nil, nil)
    }
    
    private func extractTitle(from html: String) -> String? {
        // Basic title extraction - could be made more robust
        if let titleRange = html.range(of: "<title>.*?</title>", options: .regularExpression) {
            let title = html[titleRange]
                .replacingOccurrences(of: "<title>", with: "")
                .replacingOccurrences(of: "</title>", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return title.isEmpty ? nil : title
        }
        return nil
    }
    
    private func extractVersion(from html: String) -> String? {
        // Basic version extraction - could be made more robust
        if let metaRange = html.range(of: "content=\".*?version.*?\"", options: .regularExpression) {
            let version = html[metaRange]
                .replacingOccurrences(of: "content=\"", with: "")
                .replacingOccurrences(of: "\"", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return version.isEmpty ? nil : version
        }
        return nil
    }
    
    private func loadCachedModels() {
        if let data = cachedServerModelsData,
           let decoded = try? JSONDecoder().decode([String: [String]].self, from: data) {
            // Convert string keys back to UUIDs
            cachedServerModels = Dictionary(uniqueKeysWithValues: decoded.compactMap { key, value in
                guard let uuid = UUID(uuidString: key) else { return nil }
                return (uuid, value)
            })
        }
    }
    
    func updateCachedModels(serverId: UUID, models: [String]) {
        cachedServerModels[serverId] = models
    }
    
    func getCachedModels(for serverId: UUID) -> [String] {
        return cachedServerModels[serverId] ?? []
    }
}

enum Role: String, Codable {
    case assistant
    case user
    case system
}

@Model
class Message {
    @Attribute(.unique) var id: UUID
    var role: Role
    var content: String
    var timestamp: Date
    var generatingTime: TimeInterval?
    
    @Relationship(inverse: \Thread.messages) var thread: Thread?
    
    init(role: Role, content: String, thread: Thread? = nil, generatingTime: TimeInterval? = nil) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.timestamp = Date()
        self.thread = thread
        self.generatingTime = generatingTime
    }
}

@Model
final class Thread {
    @Attribute(.unique) let id: UUID
    var timestamp: Date
    var messages: [Message]
    
    init() {
        self.id = UUID()
        self.timestamp = Date()
        self.messages = []
    }
    
    var sortedMessages: [Message] {
        messages.sorted { $0.timestamp < $1.timestamp }
    }
}

extension Thread: @unchecked Sendable {}

enum AppTintColor: String, CaseIterable {
    case monochrome, blue, brown, gray, green, indigo, mint, orange, pink, purple, red, teal, yellow
    
    func getColor() -> Color {
        switch self {
        case .monochrome:
            .primary
        case .blue:
            .blue
        case .red:
            .red
        case .green:
            .green
        case .yellow:
            .yellow
        case .brown:
            .brown
        case .gray:
            .gray
        case .indigo:
            .indigo
        case .mint:
            .mint
        case .orange:
            .orange
        case .pink:
            .pink
        case .purple:
            .purple
        case .teal:
            .teal
        }
    }
}

enum AppFontDesign: String, CaseIterable {
    case standard, monospaced, rounded, serif
    
    func getFontDesign() -> Font.Design {
        switch self {
        case .standard:
            .default
        case .monospaced:
            .monospaced
        case .rounded:
            .rounded
        case .serif:
            .serif
        }
    }
}

enum AppFontWidth: String, CaseIterable {
    case compressed, condensed, expanded, standard
    
    func getFontWidth() -> Font.Width {
        switch self {
        case .compressed:
            .compressed
        case .condensed:
            .condensed
        case .expanded:
            .expanded
        case .standard:
            .standard
        }
    }
}

enum AppFontSize: String, CaseIterable {
    case xsmall, small, medium, large, xlarge
    
    func getFontSize() -> DynamicTypeSize {
        switch self {
        case .xsmall:
            .xSmall
        case .small:
            .small
        case .medium:
            .medium
        case .large:
            .large
        case .xlarge:
            .xLarge
        }
    }
}

enum ModelSource {
    case local
    case server
}

