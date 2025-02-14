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
import Observation

enum LLMEvaluatorError: Error {
    case modelNotFound(String)
}

@Observable
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
    var serverModels: [String] = []
    var selectedServerModel: String?
    var startTime: Date?
    var isLoadingModels = false
    
    var elapsedTime: TimeInterval? {
        if let startTime {
            return Date().timeIntervalSince(startTime)
        }
        return nil
    }

    var modelConfiguration = ModelConfiguration.defaultModel
    var loadState = LoadState.idle

    enum LoadState {
        case idle
        case loaded(ModelContainer)
    }

    /// parameters controlling the output
    let generateParameters = GenerateParameters(temperature: 0.5)
    let maxTokens = 4096
    let displayEveryNTokens = 4

    // Add a property to store AppManager
    private weak var appManager: AppManager?

    // Add new property to track reasoning steps
    var reasoningSteps: [String] = []

    init(appManager: AppManager) {
        self.appManager = appManager
        
        // Restore server models if we have a current server
        if let server = appManager.currentServer {
            Task {
                await MainActor.run {
                    // First load cached models
                    serverModels = appManager.getCachedModels(for: server.id)
                    
                    // Then fetch fresh models in background
                    Task {
                        let models = await fetchServerModels(for: server)
                        if !models.isEmpty {
                            await MainActor.run {
                                serverModels = models
                                appManager.updateCachedModels(serverId: server.id, models: models)
                            }
                        }
                    }
                }
            }
        }
    }

    func switchModel(_ model: ModelConfiguration) async {
        progress = 0.0 // reset progress
        loadState = .idle
        modelConfiguration = model
        _ = try? await load(modelName: model.name)
    }

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

    @MainActor
    func generate(modelName: String, thread: Thread, systemPrompt: String = "") async -> String {
        guard let appManager = appManager else { return "No app manager configured" }
        
        // Check if this is an image generation request
        if modelName.hasPrefix("dall-e") {
            do {
                guard let lastMessage = thread.messages.last else {
                    return "No prompt provided"
                }
                return try await generateImage(prompt: lastMessage.content)
            } catch {
                return "Image generation failed: \(error.localizedDescription)"
            }
        }
        
        guard !running else {
            print("Already running, skipping new request")
            return ""
        }
        
        await MainActor.run {
            running = true
            isThinking = true
            startTime = Date()
            output = ""
        }
        
        defer {
            Task { @MainActor in
                running = false
                isThinking = false
                startTime = nil
            }
        }
        
        if appManager.isUsingServer {
            print("Using server mode")
            return await generateWithServer(thread: thread, systemPrompt: systemPrompt)
        } else {
            print("Using local mode")
            return await generateWithLocalModel(modelName: modelName, thread: thread, systemPrompt: systemPrompt)
        }
    }
    
    private func generateWithServer(thread: Thread, systemPrompt: String) async -> String {
        guard let appManager = self.appManager,
              let server = appManager.currentServer,
              let modelName = appManager.currentModelName else {
            return "Error: Server configuration not available"
        }
        
        let finalServerType = server.type
        let serverURL = server.url
        
        print("🔵 Server type: \(String(describing: finalServerType))")
        print("🔵 Current model: \(modelName)")
        print("🔵 Current server URL: \(serverURL)")
        
        // Build request
        guard let url = URL(string: serverURL)?.appendingPathComponent("chat/completions") else {
            return "Error: Invalid server URL"
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if !server.apiKey.isEmpty {
            request.setValue("Bearer \(server.apiKey)", forHTTPHeaderField: "Authorization")
        }
        
        // Build request body based on server type
        let messages = thread.sortedMessages.map { message in
            [
                "role": message.role.rawValue,
                "content": message.content
            ]
        }
        
        var allMessages: [[String: String]]
        
        // Initialize the base body structure with common parameters
        var body: [String: Any] = [
            "stream": true,
            "model": modelName,
            "temperature": 1
        ]

        // Handle different server types
        switch finalServerType {
        case .openai:
            // For OpenAI models starting with "o", use "user" role
            let systemRole = modelName.hasPrefix("o") ? "user" : "system"
            let systemMessage = ["role": systemRole, "content": systemPrompt]
            allMessages = [systemMessage] + messages

            // Update the body parameters for different model types
            if modelName.hasPrefix("dall-e") {
                // Configure for image generation
                body["n"] = 1
                body["size"] = "1024x1024"
                body["quality"] = "standard"
                body["response_format"] = "url"
                // Extract the prompt from the last message
                if let lastMessage = messages.last {
                    body["prompt"] = lastMessage["content"]
                }
            } else if modelName.hasPrefix("o1-") {
                body["max_completion_tokens"] = 2000  // Use max_completion_tokens for o1 models
            } else {
                body["max_tokens"] = 2000  // Use max_tokens for other models
            }
        default:
            // For other servers, include system message and ttl
            let systemMessage = ["role": "system", "content": systemPrompt]
            allMessages = [systemMessage] + messages
            body["max_tokens"] = 2000
            body["ttl"] = 600
        }

        // Add messages to body after they're prepared
        body["messages"] = allMessages
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: body)
            request.httpBody = jsonData
            print("📤 Sending request with body: \(String(data: jsonData, encoding: .utf8) ?? "")")
            
            let (bytes, _) = try await URLSession.shared.bytes(for: request)
            var fullResponse = ""
            reasoningSteps.removeAll() // Clear previous reasoning steps
            
            for try await line in bytes.lines {
                print("📩 Received line: \(line)")
                
                guard !line.isEmpty else { 
                    print("⚠️ Empty line, skipping")
                    continue 
                }
                guard line != "data: [DONE]" else { 
                    print("✅ Received DONE signal")
                    break 
                }
                guard line.hasPrefix("data: ") else { 
                    print("⚠️ Line doesn't start with 'data: ', skipping")
                    continue 
                }
                
                let jsonString = String(line.dropFirst(6))
                print("🔍 Parsing JSON string: \(jsonString)")
                
                guard let jsonData = jsonString.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                    print("❌ Failed to parse JSON data")
                    continue
                }
                
                print("📋 Parsed JSON: \(json)")
                
                // Handle OpenAI format with reasoning
                if finalServerType == .openai {
                    if modelName.hasPrefix("dall-e") {
                        if let data = json["data"] as? [[String: Any]],
                           let firstImage = data.first,
                           let imageUrl = firstImage["url"] as? String {
                            // Return the image URL in the response
                            fullResponse = "![Generated Image](\(imageUrl))"
                            await updateOutput(fullResponse)
                        }
                    } else if let choices = json["choices"] as? [[String: Any]] {
                        if let firstChoice = choices.first,
                           let delta = firstChoice["delta"] as? [String: Any] {
                            
                            // Check for tool calls (reasoning steps)
                            if let toolCalls = delta["tool_calls"] as? [[String: Any]] {
                                for toolCall in toolCalls {
                                    if let function = toolCall["function"] as? [String: Any],
                                       let name = function["name"] as? String,
                                       let arguments = function["arguments"] as? String {
                                        reasoningSteps.append("🤔 \(name): \(arguments)")
                                        await updateOutput(fullResponse + "\n\n" + reasoningSteps.joined(separator: "\n"))
                                    }
                                }
                            }
                            
                            // Handle regular content
                            if let content = delta["content"] as? String {
                                fullResponse += content
                                await updateOutput(fullResponse + "\n\n" + reasoningSteps.joined(separator: "\n"))
                            }
                        }
                    }
                } else {
                    // Handle other servers (Ollama, LM Studio)
                    if let choices = json["choices"] as? [[String: Any]],
                       let delta = choices.first?["delta"] as? [String: Any],
                       let content = delta["content"] as? String {
                        fullResponse += content
                        await updateOutput(fullResponse)
                    }
                }
            }
            
            print("🏁 Final response: \(fullResponse)")
            return fullResponse
            
        } catch {
            print("❌ Error generating response: \(error)")
            await updateOutput("Error: \(error.localizedDescription)")
            return await output
        }
    }
    
    private func generateWithLocalModel(modelName: String, thread: Thread, systemPrompt: String) async -> String {
        print("Starting local model generation with model: \(modelName)")
        guard !running else { 
            print("Already running, returning empty")
            return "" 
        }

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
        }

        running = false
        return output
    }

    @MainActor
    func fetchServerModels(for server: ServerConfig) async -> [String] {
        guard !server.url.isEmpty,
              let url = URL(string: server.url)?.appendingPathComponent("models") else {
            return []
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if !server.apiKey.isEmpty {
            request.setValue("Bearer \(server.apiKey)", forHTTPHeaderField: "Authorization")
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let models = json["data"] as? [[String: Any]] {
                return models.compactMap { $0["id"] as? String }
            }
        } catch {
            print("❌ Error fetching models: \(error.localizedDescription)")
        }
        return []
    }

    @MainActor
    private func updateOutput(_ newOutput: String) {
        output = newOutput
    }
    
    @MainActor
    private func updateProgress(_ newProgress: Double) {
        progress = newProgress
    }

    // Add new function for image generation
    /// Generates an image using the DALL-E API
    /// - Parameter prompt: The text description of the image to generate
    /// - Returns: A markdown-formatted string containing the generated image URL
    /// - Throws: NSError if the server configuration is invalid or the API request fails
    @MainActor
    func generateImage(prompt: String) async throws -> String {
        guard let appManager = appManager,
              let serverConfig = appManager.currentServer,
              let modelName = appManager.currentModelName else {
            throw NSError(domain: "LLMEvaluator", code: -1, userInfo: [NSLocalizedDescriptionKey: "No server configured"])
        }
        
        guard let url = URL(string: serverConfig.url)?.appendingPathComponent("images/generations") else {
            throw NSError(domain: "LLMEvaluator", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        // Configure based on model version
        let size = modelName == "dall-e-2" ? "1024x1024" : "1024x1024"
        let quality = modelName == "dall-e-2" ? "standard" : "standard"
        
        let body: [String: Any] = [
            "prompt": prompt,
            "n": 1,
            "size": size,
            "quality": quality,
            "response_format": "url",
            "model": modelName  // Use the selected model (dall-e-2 or dall-e-3)
        ]
        
        print("🖼️ Using model: \(modelName) for image generation")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(serverConfig.apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        print("🖼️ Sending image generation request to: \(url)")
        let (data, _) = try await URLSession.shared.data(for: request)
        
        do {
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            
            if let error = json?["error"] as? [String: Any],
               let message = error["message"] as? String {
                print("🔴 OpenAI Error: \(message)")
                throw NSError(domain: "OpenAI", code: -1, userInfo: [NSLocalizedDescriptionKey: message])
            }
            
            guard let dataArray = json?["data"] as? [[String: Any]],
                  let firstImage = dataArray.first,
                  let imageUrl = firstImage["url"] as? String else {
                throw NSError(domain: "OpenAI", code: -1, userInfo: [NSLocalizedDescriptionKey: "No image URL in response"])
            }
            
            return "![Generated Image](\(imageUrl))"
        } catch {
            print("🔴 Image generation error: \(error)")
            throw error
        }
    }
}

private extension String {
    func stripPrefix(_ prefix: String) -> String? {
        guard self.hasPrefix(prefix) else { return nil }
        return String(self.dropFirst(prefix.count))
    }
}
