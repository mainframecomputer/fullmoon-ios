import AppIntents
import SwiftData
import SwiftUI

@available(iOS 16.0, macOS 13.0, *)
struct RequestLLMIntent: AppIntent {
    static var title: LocalizedStringResource = "new chat"
    static var description: LocalizedStringResource = "start a new chat"
    
    @Parameter(title: "message", requestValueDialog: IntentDialog("new chat"))
    var prompt: String

    static var parameterSummary: some ParameterSummary {
        Summary("new chat with \(\.$prompt)")
    }
    
    let thread = Thread() // create a new thread for this intent

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let llm = LLMEvaluator()
        let appManager = AppManager()
        
        if prompt.isEmpty {
            if let output = thread.messages.last?.content {
                return .result(value: output) // if prompt is empty and this is not the first message, return the result
            } else {
                throw $prompt.requestValue("new chat") // re-prompt
            }
        }

        if let modelName = appManager.currentModelName {
            _ = try? await llm.load(modelName: modelName)
            
            let message = Message(role: .user, content: prompt, thread: thread)
            thread.messages.append(message)
            let output = await llm.generate(modelName: modelName, thread: thread, systemPrompt: appManager.systemPrompt)
            let responseMessage = Message(role: .assistant, content: output, thread: thread)
            thread.messages.append(responseMessage)

            throw $prompt.requestValue("\(output)") // re-prompt infinitely until user cancels
            
            return .result(value: output)
        }
        else {
            let error = "no model is currently selected. open the app and select a model first."
            return .result(value: error)
        }
    }

    static var openAppWhenRun: Bool = false
}
