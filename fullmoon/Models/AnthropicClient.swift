//
//  AnthropicClient.swift
//  fullmoon
//
//  Created on 10/31/24.
//

import Foundation

struct AnthropicMessage: Codable {
    let role: String
    let content: String
}

struct AnthropicRequest: Codable {
    let model: String
    let messages: [AnthropicMessage]
    let max_tokens: Int
    let temperature: Double
    let stream: Bool
    let system: String?
}

struct AnthropicResponse: Codable {
    let id: String
    let type: String
    let role: String
    let content: [AnthropicContent]
    let model: String
    let stop_reason: String?
    let stop_sequence: String?
    let usage: AnthropicUsage
}

struct AnthropicContent: Codable {
    let type: String
    let text: String
}

struct AnthropicUsage: Codable {
    let input_tokens: Int
    let output_tokens: Int
}

struct AnthropicStreamEvent: Codable {
    let type: String
    let message: AnthropicStreamMessage?
    let index: Int?
    let delta: AnthropicDelta?
    let content_block: AnthropicContentBlock?
    let usage: AnthropicUsage?
}

struct AnthropicStreamMessage: Codable {
    let id: String
    let type: String
    let role: String
    let content: [String]
    let model: String
    let stop_reason: String?
    let stop_sequence: String?
    let usage: AnthropicUsage
}

struct AnthropicDelta: Codable {
    let type: String?
    let text: String?
    let stop_reason: String?
    let stop_sequence: String?
}

struct AnthropicContentBlock: Codable {
    let type: String
    let text: String
}

struct AnthropicError: Codable {
    let type: String
    let error: AnthropicErrorDetail
}

struct AnthropicErrorDetail: Codable {
    let type: String
    let message: String
}

enum AnthropicClientError: Error, LocalizedError {
    case invalidURL
    case noData
    case decodingError(Error)
    case apiError(String)
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .noData:
            return "No data received from API"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .apiError(let message):
            return "API Error: \(message)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

@MainActor
class AnthropicClient: ObservableObject {
    private let apiKey: String
    private let baseURL = "https://api.anthropic.com/v1/messages"
    private let session = URLSession.shared
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    func streamChat(messages: [AnthropicMessage], systemPrompt: String?, temperature: Double = 0.5, maxTokens: Int = 4096) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    guard let url = URL(string: baseURL) else {
                        throw AnthropicClientError.invalidURL
                    }
                    
                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
                    request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
                    
                    let requestBody = AnthropicRequest(
                        model: "claude-3-opus-20240229",
                        messages: messages,
                        max_tokens: maxTokens,
                        temperature: temperature,
                        stream: true,
                        system: systemPrompt
                    )
                    
                    request.httpBody = try JSONEncoder().encode(requestBody)
                    
                    let (bytes, response) = try await session.bytes(for: request)
                    
                    guard let httpResponse = response as? HTTPURLResponse else {
                        throw AnthropicClientError.networkError(URLError(.badServerResponse))
                    }
                    
                    if httpResponse.statusCode != 200 {
                        var errorMessage = "HTTP \(httpResponse.statusCode)"
                        if let data = try? Data(contentsOf: url),
                           let error = try? JSONDecoder().decode(AnthropicError.self, from: data) {
                            errorMessage = error.error.message
                        }
                        throw AnthropicClientError.apiError(errorMessage)
                    }
                    
                    var buffer = ""
                    
                    for try await line in bytes.lines {
                        if line.hasPrefix("data: ") {
                            let jsonStr = String(line.dropFirst(6))
                            
                            if jsonStr == "[DONE]" {
                                continuation.finish()
                                return
                            }
                            
                            if let data = jsonStr.data(using: .utf8) {
                                do {
                                    let event = try JSONDecoder().decode(AnthropicStreamEvent.self, from: data)
                                    
                                    if event.type == "content_block_delta",
                                       let delta = event.delta,
                                       let text = delta.text {
                                        buffer += text
                                        continuation.yield(buffer)
                                    } else if event.type == "message_stop" {
                                        continuation.finish()
                                        return
                                    }
                                } catch {
                                    // Skip malformed JSON lines
                                    continue
                                }
                            }
                        }
                    }
                    
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
