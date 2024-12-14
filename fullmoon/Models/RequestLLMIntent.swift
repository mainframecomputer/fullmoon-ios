import AppIntents
import SwiftUI
import SwiftData

@available(iOS 16.0, macOS 13.0, *)
struct RequestLLMIntent: AppIntent {
    static var title: LocalizedStringResource = "Request LLM"
    static var description: LocalizedStringResource = "Send a prompt to the LLM and get a response"
    
    @Parameter(title: "Prompt")
    var prompt: String
    
    static var parameterSummary: some ParameterSummary {
        Summary("Request LLM with \(\.$prompt)")
    }
    
    @MainActor
    func perform() async throws -> some ReturnsValue<String> {
        let llm = LLMEvaluator()
        let appManager = AppManager()
        
        if let modelName = appManager.currentModelName {
            _ = try? await llm.load(modelName: modelName)
            let thread = Thread()
            let output = await llm.generate(modelName: modelName, thread: thread, systemPrompt: appManager.systemPrompt)
            return .result(value: output)
        } else {
            return .result(value: "No model is currently selected. Please open the app and select a model first.")
        }
    }
}

extension RequestLLMIntent {
    static var openAppWhenRun: Bool = false
} 
