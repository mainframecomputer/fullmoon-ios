//
//  Models.swift
//  fullmoon
//
//  Created by Jordan Singer on 10/4/24.
//

import MLXLMCommon
import Foundation

extension ModelConfiguration: @retroactive Equatable {
    public static func == (lhs: MLXLMCommon.ModelConfiguration, rhs: MLXLMCommon.ModelConfiguration) -> Bool {
        return lhs.name == rhs.name
    }
    
    public static let llama_3_2_1B_4bit = ModelConfiguration(
        id: "mlx-community/Llama-3.2-1B-Instruct-4bit"
    )
    
    public static let llama_3_2_3b_4bit = ModelConfiguration(
        id: "mlx-community/Llama-3.2-3B-Instruct-4bit"
    )
    
    public static let deepseek_r1_distill_qwen_1_5b = ModelConfiguration(
        id: "mlx-community/deepseek-r1-distill-qwen-1.5b"
    )
    
    public static var availableModels: [ModelConfiguration] = [
        llama_3_2_1B_4bit,
        llama_3_2_3b_4bit
        deepseek_r1_distill_qwen_1_5b
    ]
    
    public static var defaultModel: ModelConfiguration {
        llama_3_2_1B_4bit
    }
    
    public static func getModelByName(_ name: String) -> ModelConfiguration? {
        if let model = availableModels.first(where: { $0.name == name }) {
            return model
        } else {
            return nil
        }
    }
    
    func getPromptHistory(thread: Thread, systemPrompt: String) -> [[String: String]] {
        var history: [[String: String]] = []
        
        // system prompt
        history.append([
            "role": "system",
            "content": systemPrompt
        ])

        // messages
        for message in thread.sortedMessages {
            history.append([
                "role": message.role.rawValue,
                "content": message.content
            ])
        }
        
        return history
    }
    
    /// Returns the model's approximate size, in GB.
    public var modelSize: Decimal? {
        switch self {
        case .llama_3_2_1B_4bit: return 0.7
        case .llama_3_2_3b_4bit: return 1.8
        case .deepseek_r1_distill_qwen_1_5b: return 1.0
        default: return nil
        }
    }
}
