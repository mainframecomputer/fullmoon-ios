//
//  AnthropicModels.swift
//  fullmoon
//
//  Created on 10/31/24.
//

import Foundation

struct AnthropicModel: Identifiable, Equatable {
    let id: String
    let name: String
    let contextWindow: Int
    let description: String
    let isLatest: Bool
    
    static let availableModels = [
        AnthropicModel(
            id: "claude-3-5-sonnet-20241022",
            name: "Claude 3.5 Sonnet",
            contextWindow: 200000,
            description: "Most intelligent model",
            isLatest: true
        ),
        AnthropicModel(
            id: "claude-3-5-haiku-20241022", 
            name: "Claude 3.5 Haiku",
            contextWindow: 200000,
            description: "Fast and efficient",
            isLatest: true
        ),
        AnthropicModel(
            id: "claude-3-opus-20240229",
            name: "Claude 3 Opus",
            contextWindow: 200000,
            description: "Powerful model for complex tasks",
            isLatest: false
        ),
        AnthropicModel(
            id: "claude-3-sonnet-20240229",
            name: "Claude 3 Sonnet",
            contextWindow: 200000,
            description: "Balanced performance",
            isLatest: false
        ),
        AnthropicModel(
            id: "claude-3-haiku-20240307",
            name: "Claude 3 Haiku",
            contextWindow: 200000,
            description: "Fastest model",
            isLatest: false
        )
    ]
    
    static let defaultModel = availableModels[0] // Claude 3.5 Sonnet
}