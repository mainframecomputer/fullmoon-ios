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
import UserNotifications

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
        if self.progress >= 0.80 && !self.isModelFullyLoaded {
            self.isPaused = true
        }
    }

    @objc private func handleResume() {
        if self.progress >= 0.80 && !self.isModelFullyLoaded {
            self.isPaused = false
            // Optionally resume final model loading here if needed.
        }
    }

    func switchModel(_ model: ModelConfiguration) async {
        progress = 0.0 // reset progress
        loadState = .idle
        modelConfiguration = model
        // Clear any existing Live Activities before starting new download
        await cleanupExistingActivities()
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
        
        // Reset state for new download
        self.isDownloadComplete = false
        self.isModelFullyLoaded = false
        
        // Add retry logic for network issues
        var retryCount = 0
        let maxRetries = 3
        
        switch loadState {
        case .idle:
            // Clean up any existing activities before starting new one
            await cleanupExistingActivities()
            
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
            
            // Wrap the container loading in retry logic
            let container: ModelContainer = try await withRetry(maxAttempts: maxRetries) {
                try await LLMModelFactory.shared.loadContainer(configuration: model) { [modelConfiguration] progress in
                    Task { @MainActor in
                        self.modelInfo = "downloading \(modelConfiguration.name): \(Int(progress.fractionCompleted * 100))%"
                        self.progress = progress.fractionCompleted
                        
                        // Check if we're in background at any point during download
                        if UIApplication.shared.applicationState != .active {
                            // Only cancel the download if we reach 80% in background
                            if progress.fractionCompleted >= 0.80 {
                                if let downloadActivity = self.downloadActivity {
                                    let updatedState = ModelDownloadAttributes.ContentState(
                                        progress: progress.fractionCompleted,
                                        error: "Please return to fullmoon to finish download"
                                    )
                                    await downloadActivity.update(using: updatedState)
                                }
                                
                                // Save state before cancelling
                                NotificationCenter.default.post(
                                    name: .saveInterruptedDownload,
                                    object: nil,
                                    userInfo: ["model": modelConfiguration.name, "progress": progress.fractionCompleted]
                                )
                                
                                // If we're past 80% and go to background, we need to ensure we don't proceed
                                self.isPaused = true
                                throw LLMEvaluatorError.backgroundModeError("Please return to app to finish download")
                            }
                        } else {
                            // If we're back in foreground and were paused, we need to resume
                            if self.isPaused && progress.fractionCompleted >= 0.80 {
                                self.isPaused = false
                            }
                        }
                        
                        // Verify download progress is actually complete before proceeding
                        if progress.fractionCompleted >= 1.0 {
                            // Add a small delay to ensure all data is written
                            try? await Task.sleep(for: .seconds(1))
                            self.isDownloadComplete = true
                        }
                    }
                }
            }
            
            // Only initialize GPU when the app is active and download is truly complete
            if UIApplication.shared.applicationState == .active && self.isDownloadComplete && !self.isPaused {
                self.modelInfo = "Initializing \(modelConfiguration.id)..."
                let gpuTask = Task {
                    self.modelInfo = "Loaded \(modelConfiguration.id). Weights: \(MLX.GPU.activeMemory / 1024 / 1024)M"
                    self.loadState = .loaded(container)
                    self.isModelFullyLoaded = true
                }
                
                try? await withTimeout(seconds: 5) {
                    try await gpuTask.value
                }
            } else {
                // Be more specific about why we can't initialize GPU
                if UIApplication.shared.applicationState != .active {
                    throw LLMEvaluatorError.backgroundModeError("Cannot initialize GPU in background")
                } else if self.isPaused {
                    throw LLMEvaluatorError.backgroundModeError("Download paused - please return to app")
                } else {
                    throw LLMEvaluatorError.backgroundModeError("Download not complete")
                }
            }
            
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
        guard UIApplication.shared.applicationState == .active else {
            return "Cannot generate while app is in background"
        }
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

    // New helper: resets any active Live Activity
    func resetLiveActivity() async {
        if let downloadActivity = self.downloadActivity {
            await downloadActivity.end(dismissalPolicy: .immediate)
            self.downloadActivity = nil
            print("LLMEvaluator: Live activity has been reset.")
        }
    }

    deinit {
        Task {
            if let downloadActivity = await self.downloadActivity {
                await downloadActivity.end(dismissalPolicy: .immediate)
            }
        }
    }

    // Helper function to timeout long-running tasks
    private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw LLMEvaluatorError.backgroundModeError("GPU initialization timed out")
            }
            
            // Return the first result (either the operation completing or the timeout)
            let result = try await group.next()!
            
            // Cancel any remaining tasks
            group.cancelAll()
            
            return result
        }
    }

    // Helper function to retry operations
    private func withRetry<T>(maxAttempts: Int, operation: () async throws -> T) async throws -> T {
        var lastError: Error?
        
        for attempt in 0..<maxAttempts {
            do {
                if attempt > 0 {
                    // Add exponential backoff
                    try await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(attempt)) * 1_000_000_000))
                }
                return try await operation()
            } catch {
                lastError = error
                if let downloadActivity = self.downloadActivity {
                    let updatedState = ModelDownloadAttributes.ContentState(
                        progress: self.progress,
                        error: "Retrying download..."
                    )
                    await downloadActivity.update(using: updatedState)
                }
            }
        }
        
        throw lastError ?? LLMEvaluatorError.backgroundModeError("Max retries exceeded")
    }

    private func cleanupExistingActivities() async {
        // End the current Live Activity if it exists
        if let downloadActivity = self.downloadActivity {
            await downloadActivity.end(dismissalPolicy: .immediate)
            self.downloadActivity = nil
        }
        
        // Also end any other existing activities for this app
        for activity in Activity<ModelDownloadAttributes>.activities {
            await activity.end(dismissalPolicy: .immediate)
        }
    }
}
