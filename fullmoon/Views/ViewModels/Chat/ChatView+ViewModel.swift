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
        private(set) var lastFailedPrompt: String?
        private(set) var generatingMessageID: UUID?
        private(set) var loadPhase = AIModelLoadPhase.loading
        private(set) var loadDuration: TimeInterval?
        private(set) var firstTextDelay: TimeInterval?
        private(set) var charactersPerSecond: Double?

        private static let logger = Logger(subsystem: "com.sebastiendaguin.NoctisAi", category: "Inference")
        @ObservationIgnored private var noctisService: (any AIModelService)?
        @ObservationIgnored private let makeService: @MainActor () throws -> any AIModelService
        @ObservationIgnored private var generationTask: Task<Void, Never>?
        @ObservationIgnored private var streamingMessage: Message?
        @ObservationIgnored private var pendingResponse = ""
        @ObservationIgnored private var flushTask: Task<Void, Never>?
        @ObservationIgnored private var hasDisplayedResponse = false
        @ObservationIgnored private var responseStarted: ContinuousClock.Instant?
        @ObservationIgnored private var firstText: ContinuousClock.Instant?
        @ObservationIgnored private var characterCount = 0
        @ObservationIgnored private var drafts: [UUID: String] = [:]
        @ObservationIgnored private var currentTrackedThreadID: UUID?
        private var sessionThreadID: UUID?
        private var needsNewSession = false

        init(makeService: @escaping @MainActor () throws -> any AIModelService = {
            #if os(macOS)
            guard let search = try EmbeddedSearXNGService.bundled() else {
                throw EmbeddedSearXNGError.runtimeUnavailable
            }
            return MLXModelService(webSearchService: search)
            #elseif os(iOS)
            return MLXModelService(webSearchService: IOSWebSearchService.shared)
            #else
            return MLXModelService()
            #endif
        }) {
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

        // MARK: - Draft Management

        func updateThreadSelection(_ newThread: Thread?) {
            if let currentID = currentTrackedThreadID {
                if prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    drafts.removeValue(forKey: currentID)
                } else {
                    drafts[currentID] = prompt
                }
            }
            currentTrackedThreadID = newThread?.id
            if let newID = newThread?.id {
                prompt = drafts[newID] ?? ""
            } else {
                let emptyThreadDraftKey = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
                prompt = drafts[emptyThreadDraftKey] ?? ""
            }
        }

        func restoreLastFailedPrompt() {
            guard let failed = lastFailedPrompt, !failed.isEmpty else { return }
            prompt = failed
            lastFailedPrompt = nil
            submissionError = nil
        }

        // MARK: - Model Loading

        @discardableResult
        func loadModel() async -> Bool {
            guard !isLoading else { return false }
            if isConnected { return true }
            isLoading = true
            submissionError = nil
            defer { isLoading = false }
            let service: any AIModelService
            do {
                service = try noctisService ?? makeService()
            } catch {
                submissionError = error.localizedDescription
                return false
            }
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

        // MARK: - Send & Generation

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
            currentTrackedThreadID = thread.id
            drafts.removeValue(forKey: thread.id)
            lastFailedPrompt = text
            prompt = ""
            submissionError = nil

            startGeneration(
                text: text,
                thread: thread,
                history: history,
                response: response,
                context: context
            )
        }

        private func startGeneration(
            text: String,
            thread: Thread,
            history: [AIChatMessage],
            response: Message,
            context: ModelContext
        ) {
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
                            response.hasError = true
                            response.content = "La réponse n’a pas pu être générée."
                        } else {
                            response.generatingTime = Date().timeIntervalSince(started)
                        }
                        do {
                            try context.save()
                        } catch {
                            submissionError = error.localizedDescription
                        }
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
                    // Clear failed prompt backup upon successful completion
                    self.lastFailedPrompt = nil
                } catch is CancellationError {
                    needsNewSession = true
                    if let message = self.streamingMessage, !message.isDeleted {
                        message.isInterrupted = true
                    }
                } catch {
                    needsNewSession = true
                    submissionError = error.localizedDescription
                    if let message = self.streamingMessage, !message.isDeleted {
                        message.hasError = true
                    }
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
                    do { try await Task.sleep(for: .milliseconds(100)) }
                    catch { return }
                    self?.flushPendingResponse()
                    self?.flushTask = nil
                }
            }
        }

        private func flushPendingResponse() {
            guard !pendingResponse.isEmpty else { return }
            defer { pendingResponse = "" }
            guard let message = streamingMessage, !message.isDeleted,
                  message.modelContext != nil, let thread = message.thread, !thread.isDeleted else { return }
            message.content += pendingResponse
        }

        private static func seconds(_ duration: Duration) -> Double {
            Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18
        }

        // MARK: - In-Place Regeneration & Retrying

        /// Regenerate an assistant message in place within the current conversation
        func regenerate(_ message: Message, in thread: Thread, context: ModelContext) {
            guard !isSending, isConnected else { return }
            let sorted = thread.sortedMessages
            guard let index = sorted.firstIndex(where: { $0.id == message.id }) else { return }

            let userMessage: Message
            let historyMessages: [Message]

            if message.role == .assistant {
                guard let userIndex = sorted[..<index].lastIndex(where: { $0.role == .user }) else { return }
                userMessage = sorted[userIndex]
                historyMessages = Array(sorted[..<userIndex])
            } else {
                userMessage = message
                historyMessages = Array(sorted[..<index])
            }

            let history = historyMessages.map { msg in
                let role: AIChatMessage.Role = switch msg.role {
                case .user: .user
                case .assistant: .assistant
                case .system: .system
                }
                return AIChatMessage(role: role, content: msg.content)
            }

            let targetResponse: Message
            if message.role == .assistant {
                targetResponse = message
                targetResponse.content = ""
                targetResponse.isInterrupted = false
                targetResponse.hasError = false
                targetResponse.timestamp = Date()
            } else {
                if index + 1 < sorted.count, sorted[index + 1].role == .assistant {
                    targetResponse = sorted[index + 1]
                    targetResponse.content = ""
                    targetResponse.isInterrupted = false
                    targetResponse.hasError = false
                    targetResponse.timestamp = Date()
                } else {
                    targetResponse = Message(role: .assistant, content: "")
                    context.insert(targetResponse)
                    thread.messages.append(targetResponse)
                }
            }

            do {
                try context.save()
            } catch {
                submissionError = error.localizedDescription
                return
            }

            needsNewSession = true
            submissionError = nil
            startGeneration(
                text: userMessage.content,
                thread: thread,
                history: history,
                response: targetResponse,
                context: context
            )
        }

        /// Create a branch in a separate conversation from a given message
        func createBranch(from message: Message, in thread: Thread, context: ModelContext, select: (Thread) -> Void) {
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

        // MARK: - Edit & Delete Messages

        /// Puts the user message content back into the prompt and cleans up the subsequent exchange for re-submission
        func editUserMessage(_ message: Message, in thread: Thread, context: ModelContext) {
            guard message.role == .user else { return }
            if isSending { stop() }
            prompt = message.content

            let sorted = thread.sortedMessages
            if let userIndex = sorted.firstIndex(where: { $0.id == message.id }) {
                // Remove following assistant message if present
                if userIndex + 1 < sorted.count && sorted[userIndex + 1].role == .assistant {
                    let assistantMsg = sorted[userIndex + 1]
                    if let aIndex = thread.messages.firstIndex(where: { $0.id == assistantMsg.id }) {
                        thread.messages.remove(at: aIndex)
                    }
                    context.delete(assistantMsg)
                }
                if let uIndex = thread.messages.firstIndex(where: { $0.id == message.id }) {
                    thread.messages.remove(at: uIndex)
                }
                context.delete(message)
            }
            needsNewSession = true
            do {
                try context.save()
            } catch {
                submissionError = error.localizedDescription
            }
        }

        /// Deletes a single message
        func deleteMessage(_ message: Message, in thread: Thread, context: ModelContext) {
            if generatingMessageID == message.id {
                stop()
            }
            if let index = thread.messages.firstIndex(where: { $0.id == message.id }) {
                thread.messages.remove(at: index)
            }
            context.delete(message)
            needsNewSession = true
            do {
                try context.save()
            } catch {
                submissionError = error.localizedDescription
            }
        }

        func stop() {
            guard isSending, !isStopping else { return }
            isStopping = true
            // withResponse waits for the engine to clean up after task cancellation.
            generationTask?.cancel()
        }
    }
}
