import AppIntents
import SwiftUI
import SwiftData

@available(iOS 16.0, macOS 13.0, *)
struct RequestLLMIntent: AppIntent {
    static var title: LocalizedStringResource = "new chat"
    static var description: LocalizedStringResource = "start a new chat"

    @Parameter(title: "message", requestValueDialog: IntentDialog("new chat"))
    var prompt: String
    
    static var parameterSummary: some ParameterSummary {
        Summary("new chat with \(\.$prompt)")
    }
        
    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog  {
        let llm = LLMEvaluator()
        let appManager = AppManager()
        
        if let modelName = appManager.currentModelName {
            _ = try? await llm.load(modelName: modelName)
            
            let thread = Thread()
            let message = Message(role: .user, content: prompt, thread: thread)
            thread.messages.append(message)
            let output = await llm.generate(modelName: modelName, thread: thread, systemPrompt: appManager.systemPrompt)
            let responseMessage = Message(role: .assistant, content: output, thread: thread)
            thread.messages.append(responseMessage)
            return .result(value: output, dialog: "\(output)")
        } else {
            let error = "no model is currently selected. open the app and select a model first."
            return .result(value: error, dialog: "\(error)")
        }
    }
    
    static var openAppWhenRun: Bool = false
}
