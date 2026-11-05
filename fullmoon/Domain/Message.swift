//
//  Message.swift
//  fullmoon
//
//  Created by Sébastien DAGUIN on 03/11/2026.
//

import Foundation
import SwiftData

@Model
class Message {
    @Attribute(.unique) var id: UUID
    var role: Role
    var content: String
    var timestamp: Date
    var generatingTime: TimeInterval?
    var isInterrupted: Bool = false
    var hasError: Bool = false
    
    @Relationship(inverse: \Thread.messages) var thread: Thread?
    
    init(
        role: Role,
        content: String,
        thread: Thread? = nil,
        generatingTime: TimeInterval? = nil,
        isInterrupted: Bool = false,
        hasError: Bool = false
    ) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.timestamp = Date()
        self.thread = thread
        self.generatingTime = generatingTime
        self.isInterrupted = isInterrupted
        self.hasError = hasError
    }
}
