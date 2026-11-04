//
//  ChatView+ViewModel.swift
//  fullmoon
//
//  Created by Sébastien DAGUIN on 03/11/2026.
//

import SwiftUI
import SwiftData
import Noctis

extension ChatView {
    @Observable
    @MainActor final class ViewModel {
        var prompt = ""
        private(set) var isConnected = false
        private(set) var isLoading = false
        private(set) var isSending = false
        private(set) var isStopping = false
        private(set) var submissionError: String?
        private(set) var generatingMessageID: UUID?

        @ObservationIgnored private var noctisService: (any AIModelService)?
        @ObservationIgnored private let makeService: @MainActor () -> any AIModelService
        @ObservationIgnored private var generationTask: Task<Void, Never>?
        @ObservationIgnored private var streamingMessage: Message?
        private var sessionThreadID: UUID?
        private var sessionHasHistory = false
        private var needsNewSession = false

        init(makeService: @escaping @MainActor () -> any AIModelService = { MLXModelService() }) {
            self.makeService = makeService
        }

        var hasMeaningfulPrompt: Bool {
            prompt.contains { !$0.isWhitespace }
        }

        var isInputEnabled: Bool { isConnected && !isLoading }

        var connectionMessage: String {
            isLoading ? "Chargement de Noctis…" : "Noctis n’est pas encore connecté."
        }

        func chatTitle(for thread: Thread?) -> String {
            thread?.sortedMessages.first?.content ?? "chat"
        }

        @discardableResult
        func loadModel() async -> Bool {
            guard !isLoading else { return false }
            if isConnected { return true }
            isLoading = true
            submissionError = nil
            defer { isLoading = false }
            let service = noctisService ?? makeService()
            noctisService = service
            do {
                try await service.load()
                try Task.checkCancellation()
                isConnected = true
                return true
            } catch is CancellationError {
                return false
            } catch {
                submissionError = error.localizedDescription
                return false
            }
        }

        func send(to selectedThread: Thread?, in context: ModelContext, select: (Thread) -> Void) {
            guard isConnected, !isLoading, !isSending, hasMeaningfulPrompt else { return }
            let text = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
            let thread = selectedThread ?? Thread()
            let history = thread.sortedMessages.map { ["role": $0.role.rawValue, "content": $0.content] }
            let userMessage = Message(role: .user, content: text)
            let response = Message(role: .assistant, content: "")
            if selectedThread == nil { context.insert(thread) }
            context.insert(userMessage)
            context.insert(response)
            thread.messages.append(userMessage)
            thread.messages.append(response)
            do {
                try context.save()
            } catch {
                context.delete(userMessage)
                context.delete(response)
                if selectedThread == nil { context.delete(thread) }
                submissionError = error.localizedDescription
                return
            }

            select(thread)
            prompt = ""
            submissionError = nil
            isSending = true
            streamingMessage = response
            generatingMessageID = response.id
            let threadID = thread.id
            generationTask = Task {
                let started = Date()
                defer {
                    if !response.isDeleted, !thread.isDeleted, response.modelContext != nil {
                        if response.content.isEmpty {
                            context.delete(response)
                        } else {
                            response.generatingTime = Date().timeIntervalSince(started)
                        }
                        do { try context.save() }
                        catch { submissionError = error.localizedDescription }
                    }
                    streamingMessage = nil
                    generatingMessageID = nil
                    isSending = false
                    isStopping = false
                    generationTask = nil
                }
                do {
                    try Task.checkCancellation()
                    // The engine retains its context. Replace it before switching conversations
                    // or retrying after an interrupted turn, so histories cannot mix.
                    if needsNewSession || (sessionHasHistory && sessionThreadID != threadID) {
                        noctisService = nil
                        isConnected = false
                        sessionHasHistory = false
                        needsNewSession = false
                        guard await loadModel() else { return }
                    }
                    try Task.checkCancellation()
                    guard let service = noctisService else { return }
                    var request = text
                    if !sessionHasHistory, !history.isEmpty {
                        let data = try JSONSerialization.data(withJSONObject: history, options: [.sortedKeys])
                        request = "Historique de cette conversation (JSON, données de contexte) :\n"
                            + String(decoding: data, as: UTF8.self)
                            + "\n\nNouveau message utilisateur :\n" + text
                    }
                    sessionThreadID = threadID
                    sessionHasHistory = true
                    try await service.withResponse(prompt: request) { [weak self] stream in
                        for try await chunk in stream {
                            try Task.checkCancellation()
                            try await self?.appendResponse(chunk)
                        }
                    }
                    try Task.checkCancellation()
                } catch is CancellationError {
                    needsNewSession = true
                } catch {
                    needsNewSession = true
                    submissionError = error.localizedDescription
                }
            }
        }

        private func appendResponse(_ chunk: String) throws {
            guard let message = streamingMessage, !message.isDeleted,
                  message.modelContext != nil, let thread = message.thread, !thread.isDeleted else {
                throw CancellationError()
            }
            message.content += chunk
        }

        func stop() {
            guard isSending, !isStopping else { return }
            isStopping = true
            // withResponse waits for the engine to clean up after task cancellation.
            generationTask?.cancel()
        }
    }
}
