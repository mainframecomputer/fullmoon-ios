//
//  LLMEvaluator.swift
//  fullmoon
//
//  Created by Jordan Singer on 10/4/24.
//

import MLX
import MLXLLM
import MLXRandom
import SwiftUI

@Observable
@MainActor
class LLMEvaluator: ObservableObject {
    var running = false
    var output = ""
    var modelInfo = ""
    var stat = ""
    var progress = 0.0

    var modelConfiguration = ModelConfiguration.defaultModel
    
    func switchModel(_ model: ModelConfiguration) async {
        progress = 0.0 // reset progress
        loadState = .idle
        modelConfiguration = model
        _ = try? await load(modelName: model.name)
    }

    /// parameters controlling the output
    let generateParameters = GenerateParameters(temperature: 0.5)
    let maxTokens = 4096

    /// update the display every N tokens -- 4 looks like it updates continuously
    /// and is low overhead.  observed ~15% reduction in tokens/s when updating
    /// on every token
    let displayEveryNTokens = 4

    enum LoadState {
        case idle
        case loaded(ModelContainer)
    }

    var loadState = LoadState.idle
    
    let impactMed = UIImpactFeedbackGenerator(style: .soft)

    /// load and return the model -- can be called multiple times, subsequent calls will
    /// just return the loaded model
    func load(modelName: String) async throws -> ModelContainer {
        let model = getModelByName(modelName)
        
        switch loadState {
        case .idle:
            // limit the buffer cache
            MLX.GPU.set(cacheLimit: 20 * 1024 * 1024)

            let modelContainer = try await MLXLLM.loadModelContainer(configuration: model!)
            {
                [modelConfiguration] progress in
                Task { @MainActor in
                    self.modelInfo =
                        "Downloading \(modelConfiguration.name): \(Int(progress.fractionCompleted * 100))%"
                    self.progress = progress.fractionCompleted
                }
            }
            self.modelInfo =
                "Loaded \(modelConfiguration.id).  Weights: \(MLX.GPU.activeMemory / 1024 / 1024)M"
            loadState = .loaded(modelContainer)
            return modelContainer

        case .loaded(let modelContainer):
            return modelContainer
        }
    }

    func generate(modelName: String, thread: Thread, systemPrompt: String) async -> String {
        guard !running else { return "" }

        running = true
        self.output = ""

        do {
            let modelContainer = try await load(modelName: modelName)
            let extraEOSTokens = modelConfiguration.extraEOSTokens

            // augment the prompt as needed
            let promptHistory = modelConfiguration.getPromptHistory(thread: thread, systemPrompt: systemPrompt)
            let prompt = modelConfiguration.prepare(prompt: promptHistory)

            let promptTokens = await modelContainer.perform { _, tokenizer in
                tokenizer.encode(text: prompt)
            }

            // each time you generate you will get something new
            MLXRandom.seed(UInt64(Date.timeIntervalSinceReferenceDate * 1000))

            let result = await modelContainer.perform { model, tokenizer in
                MLXLLM.generate(
                    promptTokens: promptTokens, parameters: generateParameters, model: model,
                    tokenizer: tokenizer, extraEOSTokens: extraEOSTokens
                ) { tokens in
                    // update the output -- this will make the view show the text as it generates
                    if tokens.count % displayEveryNTokens == 0 {
                        let text = tokenizer.decode(tokens: tokens)
                        Task { @MainActor in
                            self.output = text
                            impactMed.impactOccurred()
                        }
                    }

                    if tokens.count >= maxTokens {
                        return .stop
                    } else {
                        return .more
                    }
                }
            }

            // update the text if needed, e.g. we haven't displayed because of displayEveryNTokens
            if result.output != self.output {
                self.output = result.output
            }
            self.stat = " Tokens/second: \(String(format: "%.3f", result.tokensPerSecond))"

        } catch {
            output = "Failed: \(error)"
        }

        running = false
        return output
    }
    
    func getModelByName(_ name: String) -> ModelConfiguration? {
        if let model = ModelConfiguration.availableModels.first(where: { $0.name == name }) {
            return model
        } else {
            return nil
        }
    }
}
