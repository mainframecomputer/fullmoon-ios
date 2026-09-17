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

enum LLMEvaluatorError: LocalizedError {
    case modelNotFound(String)

    var errorDescription: String? {
        switch self {
        case let .modelNotFound(modelName):
            return "The model \(modelName) is no longer available."
        }
    }
}

enum ModelLoadStatus: Equatable {
    case idle
    case loading
    case loaded
    case failed(String)

    var errorMessage: String? {
        guard case let .failed(message) = self else { return nil }
        return message
    }
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
    private(set) var modelLoadStatus: ModelLoadStatus = .idle

    var elapsedTime: TimeInterval? {
        if let startTime {
            return Date().timeIntervalSince(startTime)
        }

        return nil
    }

    private var startTime: Date?

    var modelConfiguration = ModelConfiguration.defaultModel

    @discardableResult
    func switchModel(_ model: ModelConfiguration) async -> Bool {
        progress = 0.0 // reset progress
        modelInfo = ""
        modelLoadStatus = .idle
        loadState = .idle
        modelConfiguration = model

        do {
            _ = try await load(modelName: model.name)
            return true
        } catch {
            return false
        }
    }

    private func loadContainerWithRetry(
        configuration: ModelConfiguration,
        retriesRemaining: Int = 1
    ) async throws -> ModelContainer {
        do {
            return try await LLMModelFactory.shared.loadContainer(configuration: configuration) {
                [configuration] progress in
                Task { @MainActor in
                    self.modelInfo =
                        "Downloading \(configuration.name): \(Int(progress.fractionCompleted * 100))%"
                    self.progress = progress.fractionCompleted
                }
            }
        } catch {
            guard !isCancellationError(error) else {
                throw CancellationError()
            }
            guard retriesRemaining > 0, isTransientNetworkError(error) else {
                throw error
            }

            modelInfo = "Connection interrupted. Retrying \(configuration.name)…"
            try await Task.sleep(nanoseconds: 1_500_000_000)
            return try await loadContainerWithRetry(
                configuration: configuration,
                retriesRemaining: retriesRemaining - 1
            )
        }
    }

    private func isCancellationError(_ error: Error) -> Bool {
        if error is CancellationError { return true }

        let error = error as NSError
        return error.domain == NSURLErrorDomain && error.code == URLError.cancelled.rawValue
    }

    private func isTransientNetworkError(_ error: Error) -> Bool {
        var currentError: NSError? = error as NSError

        while let currentErrorValue = currentError {
            if currentErrorValue.domain == NSURLErrorDomain {
                switch URLError.Code(rawValue: currentErrorValue.code) {
                case .timedOut,
                     .cannotFindHost,
                     .cannotConnectToHost,
                     .networkConnectionLost,
                     .dnsLookupFailed,
                     .notConnectedToInternet,
                     .resourceUnavailable,
                     .cannotLoadFromNetwork,
                     .backgroundSessionWasDisconnected:
                    return true
                default:
                    return false
                }
            }

            currentError = currentErrorValue.userInfo[NSUnderlyingErrorKey] as? NSError
        }

        return false
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
            let error = LLMEvaluatorError.modelNotFound(modelName)
            modelLoadStatus = .failed(error.localizedDescription)
            throw error
        }

        switch loadState {
        case .idle:
            // limit the buffer cache
            MLX.GPU.set(cacheLimit: 20 * 1024 * 1024)

            modelLoadStatus = .loading

            do {
                let modelContainer = try await loadContainerWithRetry(configuration: model)
                try Task.checkCancellation()
                modelInfo =
                    "Loaded \(modelConfiguration.id).  Weights: \(MLX.GPU.activeMemory / 1024 / 1024)M"
                progress = 1.0
                loadState = .loaded(modelContainer)
                modelLoadStatus = .loaded
                return modelContainer
            } catch is CancellationError {
                modelInfo = ""
                progress = 0.0
                modelLoadStatus = .idle
                throw CancellationError()
            } catch {
                modelInfo = "Failed to load \(modelConfiguration.name): \(error.localizedDescription)"
                modelLoadStatus = .failed(error.localizedDescription)
                throw error
            }

        case let .loaded(modelContainer):
            progress = 1.0
            modelLoadStatus = .loaded
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
