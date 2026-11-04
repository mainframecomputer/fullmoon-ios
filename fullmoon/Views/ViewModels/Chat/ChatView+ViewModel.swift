//
//  ChatView+ViewModel.swift
//  fullmoon
//
//  Created by Sébastien DAGUIN on 03/11/2026.
//

import SwiftUI
import SwiftData
import Noctis
import OSLog

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
        private(set) var loadPhase = AIModelLoadPhase.loading
        private(set) var loadDuration: TimeInterval?
        private(set) var firstTextDelay: TimeInterval?
        private(set) var charactersPerSecond: Double?

        private static let logger = Logger(subsystem: "com.sebastiendaguin.NoctisAi", category: "Inference")
        @ObservationIgnored private var noctisService: (any AIModelService)?
        @ObservationIgnored private let makeService: @MainActor () -> any AIModelService
        @ObservationIgnored private var generationTask: Task<Void, Never>?
        @ObservationIgnored private var streamingMessage: Message?
        @ObservationIgnored private var pendingResponse = ""
        @ObservationIgnored private var flushTask: Task<Void, Never>?
        @ObservationIgnored private var hasDisplayedResponse = false
        @ObservationIgnored private var responseStarted: ContinuousClock.Instant?
        @ObservationIgnored private var firstText: ContinuousClock.Instant?
        @ObservationIgnored private var characterCount = 0
        private var sessionThreadID: UUID?
        private var needsNewSession = false

        init(makeService: @escaping @MainActor () -> any AIModelService = { MLXModelService() }) {
            self.makeService = makeService
        }

        var hasMeaningfulPrompt: Bool {
            prompt.contains { !$0.isWhitespace }
        }

        var isInputEnabled: Bool { isConnected && !isLoading }

        var connectionMessage: String {
            guard isLoading else { return "Noctis n’est pas encore connecté." }
            switch loadPhase {
            case .downloading: return "Téléchargement…"
            case .loading: return "Chargement du modèle…"
            case .ready: return "Prêt"
            }
        }

        func chatTitle(for thread: Thread?) -> String {
            thread?.title ?? thread?.sortedMessages.first.map { String($0.content.prefix(70)) } ?? "Nouvelle conversation"
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
            let clock = ContinuousClock()
            var phaseStarted = clock.now
            var loadingSeconds = 0.0
            loadPhase = .loading
            let (phases, output) = AsyncStream<AIModelLoadPhase>.makeStream()
            let loading = Task {
                defer { output.finish() }
                try await service.load(progress: { output.yield($0) })
            }
            for await phase in phases where phase != loadPhase {
                let elapsed = Self.seconds(phaseStarted.duration(to: clock.now))
                if loadPhase == .loading { loadingSeconds += elapsed }
                Self.logger.info("Model phase \(String(describing: self.loadPhase), privacy: .public): \(elapsed) s")
                loadPhase = phase
                phaseStarted = clock.now
            }
            do {
                try await loading.value
                try Task.checkCancellation()
                loadDuration = loadingSeconds
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
            let history = thread.sortedMessages.map {
                let role: AIChatMessage.Role
                switch $0.role {
                case .user: role = .user
                case .assistant: role = .assistant
                case .system: role = .system
                }
                return AIChatMessage(role: role, content: $0.content)
            }
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
            pendingResponse = ""
            hasDisplayedResponse = false
            firstTextDelay = nil
            charactersPerSecond = nil
            responseStarted = nil
            firstText = nil
            characterCount = 0
            let threadID = thread.id
            generationTask = Task {
                let started = Date()
                let clock = ContinuousClock()
                defer {
                    flushTask?.cancel()
                    flushTask = nil
                    flushPendingResponse()
                    if let responseStarted {
                        let elapsed = Self.seconds(responseStarted.duration(to: clock.now))
                        firstTextDelay = firstText.map { Self.seconds(responseStarted.duration(to: $0)) }
                        if let firstText {
                            let generationSeconds = Self.seconds(firstText.duration(to: clock.now))
                            charactersPerSecond = generationSeconds > 0 ? Double(characterCount) / generationSeconds : nil
                        }
                        Self.logger.info("Response: first text \(self.firstTextDelay ?? -1) s, total \(elapsed) s, \(self.characterCount) characters, \(self.charactersPerSecond ?? 0) characters/s")
                    }
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
                    guard let service = noctisService else { return }
                    if needsNewSession || sessionThreadID != threadID {
                        try await service.resetConversation(history: history)
                        needsNewSession = false
                    }
                    try Task.checkCancellation()
                    sessionThreadID = threadID
                    responseStarted = clock.now
                    try await service.withResponse(prompt: text) { [weak self] stream in
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
            guard !chunk.isEmpty else { return }
            if firstText == nil { firstText = ContinuousClock.now }
            characterCount += chunk.count
            pendingResponse += chunk
            if !hasDisplayedResponse {
                hasDisplayedResponse = true
                flushPendingResponse()
            }
            if flushTask == nil {
                flushTask = Task { [weak self] in
                    do { try await Task.sleep(for: .milliseconds(50)) }
                    catch { return }
                    self?.flushPendingResponse()
                    self?.flushTask = nil
                }
            }
        }

        private func flushPendingResponse() {
            defer { pendingResponse = "" }
            guard let message = streamingMessage, !message.isDeleted,
                  message.modelContext != nil, let thread = message.thread, !thread.isDeleted else { return }
            message.content += pendingResponse
        }

        private static func seconds(_ duration: Duration) -> Double {
            Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18
        }

        /// Keep the original answer intact by regenerating in a separate conversation.
        func regenerate(_ message: Message, in thread: Thread, context: ModelContext, select: (Thread) -> Void) {
            guard !isSending, isConnected,
                  let index = thread.sortedMessages.firstIndex(where: { $0.id == message.id }),
                  let userIndex = thread.sortedMessages[..<index].lastIndex(where: { $0.role == .user }) else { return }
            let messages = thread.sortedMessages
            let branch = Thread()
            branch.title = "Variante · " + String(messages[userIndex].content.prefix(60))
            context.insert(branch)
            for original in messages[..<userIndex] {
                let copy = Message(role: original.role, content: original.content)
                context.insert(copy)
                branch.messages.append(copy)
            }
            let draft = prompt
            prompt = messages[userIndex].content
            needsNewSession = true
            send(to: branch, in: context, select: select)
            prompt = draft
        }

        func stop() {
            guard isSending, !isStopping else { return }
            isStopping = true
            // withResponse waits for the engine to clean up after task cancellation.
            generationTask?.cancel()
        }
    }
}
