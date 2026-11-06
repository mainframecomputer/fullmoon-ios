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
    private(set) var modelStatus = ModelStatus.notDownloaded
    private var loadTask: Task<ModelContainer, Error>?
    private var loadID: UUID?

    var isLoading: Bool { loadTask != nil }

    var progress = 0.0
    var thinkingTime: TimeInterval?
    var collapsed: Bool = false
    var isThinking: Bool = false

    var elapsedTime: TimeInterval? {
        if let startTime {
            return Date().timeIntervalSince(startTime)
        }

        return nil
    }

    private var startTime: Date?

    private(set) var modelConfiguration = ModelConfiguration.defaultModel

    func switchModel(_ model: ModelConfiguration) async {
        guard loadTask == nil else { return }
        #if os(iOS)
        let model = ModelConfiguration.defaultModel
        #endif
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

    func refreshModelStatus() {
        guard loadTask == nil else { return }
        if case .loaded = loadState {
            modelStatus = .ready
        } else if case .failed = modelStatus {
            return
        } else {
            modelStatus = ModelStatus.cachedStatus(in: modelConfiguration.modelDirectory())
        }
    }

    /// Reuse the current container or share an in-flight MLX load.
    func load(modelName: String) async throws -> ModelContainer {
        if let loadTask {
            return try await loadTask.value
        }
        if case let .loaded(modelContainer) = loadState {
            return modelContainer
        }

        #if os(iOS)
        let model = ModelConfiguration.defaultModel
        #else
        guard let model = ModelConfiguration.getModelByName(modelName) else {
            modelStatus = .failed("Unknown model: \(modelName)")
            throw LLMEvaluatorError.modelNotFound(modelName)
        }
        #endif

        modelConfiguration = model
        progress = 0
        modelStatus = ModelStatus.cachedStatus(in: model.modelDirectory()) == .downloaded
            ? .loading : .downloading(0)
        let id = UUID()
        loadID = id

        // Share one load between startup, Settings and generation.
        let task = Task { @MainActor in
            MLX.GPU.set(cacheLimit: 20 * 1024 * 1024)
            return try await LLMModelFactory.shared.loadContainer(configuration: model) { progress in
                let fraction = progress.fractionCompleted
                Task { @MainActor in
                    guard self.loadID == id else { return }
                    self.modelStatus.updateDownloadProgress(fraction)
                    self.progress = self.modelStatus.downloadProgress ?? self.progress
                    self.modelInfo = "Downloading \(model.name): \(Int(self.progress * 100))%"
                }
            }
        }
        loadTask = task

        defer {
            loadID = nil
            loadTask = nil
        }
        do {
            let modelContainer = try await task.value
            progress = 1
            modelInfo = "Loaded \(model.name).  Weights: \(MLX.GPU.activeMemory / 1024 / 1024)M"
            loadState = .loaded(modelContainer)
            modelStatus = .ready
            return modelContainer
        } catch {
            loadState = .idle
            modelStatus = .failed(error.localizedDescription)
            throw error
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
}
