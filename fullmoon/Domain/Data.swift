//
//  Data.swift
//  fullmoon
//
//  Created by Jordan Singer on 10/5/24.
//

import Observation
import SwiftUI
import SwiftData

@MainActor
@Observable
final class AppManager {
    var systemPrompt: String {
        didSet { defaults.set(systemPrompt, forKey: "systemPrompt") }
    }
    var appTintColor: AppTintColor {
        didSet { defaults.set(appTintColor.rawValue, forKey: "appTintColor") }
    }
    var appFontDesign: AppFontDesign {
        didSet { defaults.set(appFontDesign.rawValue, forKey: "appFontDesign") }
    }
    var appFontSize: AppFontSize {
        didSet { defaults.set(appFontSize.rawValue, forKey: "appFontSize") }
    }
    var appFontWidth: AppFontWidth {
        didSet { defaults.set(appFontWidth.rawValue, forKey: "appFontWidth") }
    }
    var shouldPlayHaptics: Bool {
        didSet { defaults.set(shouldPlayHaptics, forKey: "shouldPlayHaptics") }
    }

    var appearance: ChatAppearance {
        didSet {
            if let data = try? JSONEncoder().encode(appearance) {
                defaults.set(data, forKey: "chatAppearance")
            }
        }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        appearance = defaults.data(forKey: "chatAppearance")
            .flatMap { try? JSONDecoder().decode(ChatAppearance.self, from: $0) } ?? ChatAppearance()
        systemPrompt = defaults.string(forKey: "systemPrompt") ?? "you are a helpful assistant"
        appTintColor = defaults.string(forKey: "appTintColor").flatMap(AppTintColor.init(rawValue:)) ?? .monochrome
        appFontDesign = defaults.string(forKey: "appFontDesign").flatMap(AppFontDesign.init(rawValue:)) ?? .standard
        appFontSize = defaults.string(forKey: "appFontSize").flatMap(AppFontSize.init(rawValue:)) ?? .medium
        appFontWidth = defaults.string(forKey: "appFontWidth").flatMap(AppFontWidth.init(rawValue:)) ?? .standard
        shouldPlayHaptics = defaults.object(forKey: "shouldPlayHaptics") as? Bool ?? true
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
        
    func playHaptic() {
        if shouldPlayHaptics {
            #if os(iOS)
            let impact = UIImpactFeedbackGenerator(style: .soft)
            impact.impactOccurred()
            #endif
        }
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
