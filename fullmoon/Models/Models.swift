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

    public static let llama_3_2_11b_vision_4bit = ModelConfiguration(
        id: "mlx-community/Llama-3.2-11B-Vision-Instruct-4bit"
    )
    
    public static let qwen_2_5_3b_4bit = ModelConfiguration(
        id: "mlx-community/Qwen2.5-3B-Instruct-4bit"
    )

    public static let qwen_2_5_0_5b_4bit = ModelConfiguration(
        id: "mlx-community/Qwen2.5-0.5B-Instruct-4bit"
    )
    
    public static let qwen_2_5_7b_4bit = ModelConfiguration(
        id: "mlx-community/Qwen2.5-7B-Instruct-4bit"
    )
    
    public static let qwen_2_5_14b_4bit = ModelConfiguration(
        id: "mlx-community/Qwen2.5-14B-Instruct-4bit"
    )
    
    public static let qwen_2_5_32b_4bit = ModelConfiguration(
        id: "mlx-community/Qwen2.5-32B-Instruct-4bit"
    )
    
    public static let sky_t1_32b_preview_4bit = ModelConfiguration(
        id: "mlx-community/Sky-T1-32B-Preview-4bit"
    )

    public static let mistral_nemo_instruct_2407_3bit = ModelConfiguration(
        id: "mlx-community/Mistral-Nemo-Instruct-2407-3bit"
    )
    
    public static var availableModels: [ModelConfiguration] = [
        llama_3_2_1B_4bit,
        llama_3_2_3b_4bit,
        llama_3_2_11b_vision_4bit,
        qwen_2_5_3b_4bit,
        qwen_2_5_0_5b_4bit,
        qwen_2_5_7b_4bit,
        qwen_2_5_14b_4bit,
        qwen_2_5_32b_4bit,
        sky_t1_32b_preview_4bit,
        mistral_nemo_instruct_2407_3bit
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
        case .llama_3_2_11b_vision_4bit: return 11.0
        case .qwen_2_5_3b_4bit: return 1.8
        case .qwen_2_5_0_5b_4bit: return 0.2
        case .qwen_2_5_7b_4bit: return 3.2
        case .qwen_2_5_14b_4bit: return 6.4
        case .qwen_2_5_32b_4bit: return 12.8
        case .sky_t1_32b_preview_4bit: return 20.0
        case .mistral_nemo_instruct_2407_3bit: return 6.0
        default: return nil
        }
    }
}
