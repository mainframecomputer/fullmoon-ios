//
//  LLMEvaluator.swift
//  fullmoon
//
//  Created by Jordan Singer on 10/4/24.
//

import MLX
import MLXLLM
import MLXLMCommon
import MLXRandom
import SwiftUI

enum LLMEvaluatorError: Error {
    case modelNotFound(String)
}

@Observable
@MainActor
class LLMEvaluator {
    var running = false
    var cancelled = false
    var output = ""
    var modelInfo = ""
    var stat = ""
    var progress = 0.0
    var thinkingTime: TimeInterval?
    var collapsed: Bool = false
    var isThinking: Bool = false
    
    private var anthropicClient: AnthropicClient?

    var elapsedTime: TimeInterval? {
        if let startTime {
            return Date().timeIntervalSince(startTime)
        }

        return nil
    }

    private var startTime: Date?

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

    /// load and return the model -- can be called multiple times, subsequent calls will
    /// just return the loaded model
    func load(modelName: String) async throws -> ModelContainer {
        guard let model = ModelConfiguration.getModelByName(modelName) else {
            throw LLMEvaluatorError.modelNotFound(modelName)
        }

        switch loadState {
        case .idle:
            // limit the buffer cache
            MLX.GPU.set(cacheLimit: 20 * 1024 * 1024)

            let modelContainer = try await LLMModelFactory.shared.loadContainer(configuration: model) {
                [modelConfiguration] progress in
                Task { @MainActor in
                    self.modelInfo =
                        "Downloading \(modelConfiguration.name): \(Int(progress.fractionCompleted * 100))%"
                    self.progress = progress.fractionCompleted
                }
            }
            modelInfo =
                "Loaded \(modelConfiguration.id).  Weights: \(MLX.GPU.activeMemory / 1024 / 1024)M"
            loadState = .loaded(modelContainer)
            return modelContainer

        case let .loaded(modelContainer):
            return modelContainer
        }
    }

    func stop() {
        isThinking = false
        cancelled = true
    }

    func generate(modelName: String, thread: Thread, systemPrompt: String) async -> String {
        guard !running else { return "" }

        running = true
        cancelled = false
        output = ""
        startTime = Date()
        
        let appManager = AppManager()
        
        // Check if we should use Anthropic API
        if appManager.selectedProvider == .anthropic {
            return await generateWithAnthropic(thread: thread, systemPrompt: systemPrompt, apiKey: appManager.anthropicAPIKey)
        }

        do {
            let modelContainer = try await load(modelName: modelName)

            // augment the prompt as needed
            let promptHistory = await modelContainer.configuration.getPromptHistory(thread: thread, systemPrompt: systemPrompt)

            if await modelContainer.configuration.modelType == .reasoning {
                isThinking = true
            }

            // each time you generate you will get something new
            MLXRandom.seed(UInt64(Date.timeIntervalSinceReferenceDate * 1000))

            let result = try await modelContainer.perform { context in
                let input = try await context.processor.prepare(input: .init(messages: promptHistory))
                return try MLXLMCommon.generate(
                    input: input, parameters: generateParameters, context: context
                ) { tokens in

                    var cancelled = false
                    Task { @MainActor in
                        cancelled = self.cancelled
                    }

                    // update the output -- this will make the view show the text as it generates
                    if tokens.count % displayEveryNTokens == 0 {
                        let text = context.tokenizer.decode(tokens: tokens)
                        Task { @MainActor in
                            self.output = text
                        }
                    }

                    if tokens.count >= maxTokens || cancelled {
                        return .stop
                    } else {
                        return .more
                    }
                }
            }

            // update the text if needed, e.g. we haven't displayed because of displayEveryNTokens
            if result.output != output {
                output = result.output
            }
            stat = " Tokens/second: \(String(format: "%.3f", result.tokensPerSecond))"

        } catch {
            output = "Failed: \(error)"
        }

        running = false
        return output
    }
    
    private func generateWithAnthropic(thread: Thread, systemPrompt: String, apiKey: String) async -> String {
        guard !apiKey.isEmpty else {
            output = "Error: No Anthropic API key configured"
            running = false
            return output
        }
        
        anthropicClient = AnthropicClient(apiKey: apiKey)
        
        // Convert thread messages to Anthropic format
        let messages = thread.sortedMessages.map { message in
            AnthropicMessage(
                role: message.role == .user ? "user" : "assistant",
                content: message.content
            )
        }
        
        do {
            let stream = anthropicClient!.streamChat(
                messages: messages,
                systemPrompt: systemPrompt,
                temperature: Double(generateParameters.temperature),
                maxTokens: maxTokens
            )
            
            var tokenCount = 0
            let streamStartTime = Date()
            
            for try await text in stream {
                if cancelled {
                    break
                }
                
                output = text
                tokenCount += 1
                
                // Calculate tokens per second
                let elapsed = Date().timeIntervalSince(streamStartTime)
                if elapsed > 0 {
                    let tokensPerSecond = Double(tokenCount) / elapsed
                    stat = " Tokens/second: \(String(format: "%.3f", tokensPerSecond))"
                }
            }
        } catch {
            output = "Error: \(error.localizedDescription)"
        }
        
        running = false
        return output
    }
}
