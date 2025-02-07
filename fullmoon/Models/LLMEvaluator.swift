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
import BackgroundTasks
import ActivityKit

enum LLMEvaluatorError: Error {
    case modelNotFound(String)
    case backgroundModeError(String)
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
    var isPaused = false
    var isModelFullyLoaded = false
    var isDownloadComplete = false

    var elapsedTime: TimeInterval? {
        if let startTime {
            return Date().timeIntervalSince(startTime)
        }

        return nil
    }

    private var startTime: Date?

    var modelConfiguration = ModelConfiguration.defaultModel

    var downloadActivity: Activity<ModelDownloadAttributes>?
    var backgroundTask: BGProcessingTask?
    var backgroundTaskIdentifier: UIBackgroundTaskIdentifier?

    init() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handlePause),
                                               name: .modelPauseNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleResume),
                                               name: .modelResumeNotification,
                                               object: nil)
    }

    @objc private func handlePause() {
        if self.progress >= 0.95 && !self.isModelFullyLoaded {
            self.isPaused = true
        }
    }

    @objc private func handleResume() {
        if self.progress >= 0.95 && !self.isModelFullyLoaded {
            self.isPaused = false
            // Optionally resume final model loading here if needed.
        }
    }

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
            // Start Live Activity for download progress first
            if ActivityAuthorizationInfo().areActivitiesEnabled {
                let initialContentState = ModelDownloadAttributes.ContentState(progress: 0)
                let activityAttributes = ModelDownloadAttributes(modelName: modelName)
                downloadActivity = try? Activity.request(
                    attributes: activityAttributes,
                    contentState: initialContentState,
                    pushType: nil
                )
            }
            
            // If we're not active, wait until the app becomes active before continuing.
            if UIApplication.shared.applicationState != .active {
                // Show clear message in Live Activity for the user.
                if let downloadActivity = self.downloadActivity {
                    let updatedState = ModelDownloadAttributes.ContentState(
                        progress: 1.0,
                        error: "Please return to app to complete download"
                    )
                    await downloadActivity.update(using: updatedState)
                }
                self.modelInfo = "Waiting for app to become active to complete download."
                // Wait until the app becomes active
                await awaitActiveState()
                // Additional brief delay to allow GPU/Metal to reinitialize
                try await Task.sleep(nanoseconds: 200_000_000)
                // Re-check the active state. If still not active, abort gracefully.
                if UIApplication.shared.applicationState != .active {
                    throw LLMEvaluatorError.backgroundModeError("App still in background. Please return to app to complete download.")
                }
            }
            
            // Now safe to proceed with model container initialization
            #if os(iOS)
            backgroundTaskIdentifier = UIApplication.shared.beginBackgroundTask { [weak self] in
                if let taskId = self?.backgroundTaskIdentifier {
                    UIApplication.shared.endBackgroundTask(taskId)
                    self?.backgroundTaskIdentifier = .invalid
                }
            }
            #endif
            
            // Directly load the container since we're already on the main actor
            let container: ModelContainer = try await LLMModelFactory.shared.loadContainer(configuration: model) { [modelConfiguration] progress in
                Task { @MainActor in
                    print("LLMEvaluator: Received progress update: \(progress.fractionCompleted)")
                    self.modelInfo = "Downloading \(modelConfiguration.name): \(Int(progress.fractionCompleted * 100))%"
                    self.progress = progress.fractionCompleted
                    
                    // Show warning at 90% if in background
                    if progress.fractionCompleted >= 0.9 && UIApplication.shared.applicationState != .active {
                        if let downloadActivity = self.downloadActivity {
                            let updatedState = ModelDownloadAttributes.ContentState(
                                progress: progress.fractionCompleted,
                                error: "Return to app to complete setup"
                            )
                            await downloadActivity.update(using: updatedState)
                        }
                    }
                    
                    // Update Live Activity with progress
                    if let downloadActivity = self.downloadActivity {
                        let updatedState = ModelDownloadAttributes.ContentState(
                            progress: progress.fractionCompleted
                        )
                        await downloadActivity.update(using: updatedState)
                    }
                    
                    if progress.fractionCompleted >= 1.0 {
                        self.isDownloadComplete = true
                    }
                }
            }
            
            // Now safe to proceed with GPU initialization
            self.modelInfo = "Loaded \(modelConfiguration.id). Weights: \(MLX.GPU.activeMemory / 1024 / 1024)M"
            self.loadState = .loaded(container)
            self.isModelFullyLoaded = true
            
            #if os(iOS)
            if let taskId = backgroundTaskIdentifier {
                UIApplication.shared.endBackgroundTask(taskId)
                backgroundTaskIdentifier = .invalid
            }
            #endif
            
            return container
            
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

        do {
            let modelContainer = try await load(modelName: modelName)

            // augment the prompt as needed
            let promptHistory = modelContainer.configuration.getPromptHistory(thread: thread, systemPrompt: systemPrompt)

            if modelContainer.configuration.modelType == .reasoning {
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
            // Post a notification with the interrupted download details
            NotificationCenter.default.post(name: .saveInterruptedDownload, object: nil, userInfo: ["model": modelName, "progress": self.progress])
            
            if let downloadActivity = self.downloadActivity {
                let errorState = ModelDownloadAttributes.ContentState(
                    progress: self.progress, 
                    error: "Download failed: \(error.localizedDescription)"
                )
                await downloadActivity.update(using: errorState)
                // Maybe wait a few seconds before ending the activity to show the error
                try? await Task.sleep(for: .seconds(3))
                await downloadActivity.end(dismissalPolicy: .immediate)
            }
        }

        running = false
        return output
    }

    private func awaitActiveState() async {
        // If already active, return immediately
        if UIApplication.shared.applicationState == .active { return }
        await withCheckedContinuation { continuation in
            var observer: NSObjectProtocol!
            observer = NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { _ in
                continuation.resume()
                NotificationCenter.default.removeObserver(observer)
            }
        }
    }
}
