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
        
    private let installedModelsKey = "installedModels"
        
    @Published var installedModels: [String] = [] {
        didSet {
            saveInstalledModelsToUserDefaults()
        }
    }
    
    init() {
        loadInstalledModelsFromUserDefaults()
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
    
    @Relationship(inverse: \Thread.messages) var thread: Thread?
    
    init(role: Role, content: String, thread: Thread? = nil) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.timestamp = Date()
        self.thread = thread
    }
}

@Model
class Thread {
    @Attribute(.unique) var id: UUID
    var title: String?
    var timestamp: Date
    
    @Relationship var messages: [Message] = []
    
    var sortedMessages: [Message] {
        return messages.sorted { $0.timestamp < $1.timestamp }
    }
    
    init() {
        self.id = UUID()
        self.timestamp = Date()
    }
}

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
