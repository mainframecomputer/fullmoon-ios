import Foundation

struct ServerConfig: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var url: String
    var apiKey: String
    var type: ServerType
    
    init(id: UUID = UUID(), name: String = "", url: String, apiKey: String = "", type: ServerType = .custom) {
        self.id = id
        self.name = name
        self.url = url
        self.apiKey = apiKey
        self.type = type
    }
    
    enum ServerType: String, Codable, CaseIterable {
        case openai = "OpenAI"
        case ollama = "Ollama"
        case lmStudio = "LM Studio"
        case custom = "Custom"
        
        var defaultURL: String {
            switch self {
            case .openai: return "https://api.openai.com/v1"
            case .ollama: return "http://localhost:11434/v1"
            case .lmStudio: return "http://localhost:1234/v1"
            case .custom: return "http"
            }
        }
    }
}