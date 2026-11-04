//
//  Thread.swift
//  fullmoon
//
//  Created by Sébastien DAGUIN on 03/11/2026.
//

import Foundation
import SwiftData
@Model
final class Thread: Sendable {
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
