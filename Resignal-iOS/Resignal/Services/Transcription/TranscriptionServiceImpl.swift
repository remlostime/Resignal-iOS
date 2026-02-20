//
//  TranscriptionServiceImpl.swift
//  Resignal
//
//  Implementation of speech-to-text transcription using Apple's Speech framework.
//

import Foundation
import Speech
import AVFoundation

/// Implementation of TranscriptionService using SFSpeechRecognizer
actor TranscriptionServiceImpl: TranscriptionService {
    
    // MARK: - Properties
    
    private let speechRecognizer: SFSpeechRecognizer?
    private let contextualStrings: [String]
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine: AVAudioEngine?
    private var liveContinuation: AsyncStream<String>.Continuation?
    
    // MARK: - Chunking Properties
    
    /// Finalized text from completed recognition chunks
    private var accumulatedTranscript: String = ""
    /// Latest partial transcript from the current chunk (used when proactively restarting)
    private var currentChunkTranscript: String = ""
    /// Timer to trigger proactive restart before hitting the 60s limit
    private var chunkRestartTask: Task<Void, Never>?
    /// Flag to prevent concurrent restart operations
    private var isRestarting: Bool = false
    /// Duration before proactively restarting recognition (before 60s limit)
    private let chunkDuration: TimeInterval = 55.0
    /// Flag to track if transcription is actively running
    private var isTranscriptionActive: Bool = false
    /// Unique identifier for the current recognition task (to ignore stale callbacks)
    private var currentTaskId: UUID?
    
    // MARK: - Previous Chunk Settlement Properties
    
    /// Task ID of the previous chunk that is still settling after endAudio()
    private var previousTaskId: UUID?
    /// The partial transcript that was committed for the previous chunk (before its final result)
    private var previousChunkSavedTranscript: String?
    /// Force-cancel timer for the previous task if it doesn't settle in time
    private var previousTaskCleanupTask: Task<Void, Never>?
    
    // MARK: - Initialization
    
    init(locale: Locale = Locale(identifier: "en-US"),
         vocabularyProvider: ContextualVocabularyProvider = ContextualVocabularyProviderImpl()) {
        self.speechRecognizer = SFSpeechRecognizer(locale: locale)
        self.contextualStrings = vocabularyProvider.allTerms()
    }
    
    // MARK: - TranscriptionService Implementation
    
    func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }
    
    nonisolated func hasPermission() -> Bool {
        SFSpeechRecognizer.authorizationStatus() == .authorized
    }
    
    func transcribe(audioURL: URL) async throws -> String {
        guard hasPermission() else {
            throw TranscriptionError.permissionDenied
        }
        
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            throw TranscriptionError.recognizerNotAvailable
        }
        
        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            throw TranscriptionError.audioFileNotFound
        }
        
        print("📝 Transcribing audio file: \(audioURL.lastPathComponent)")
        
        let request = SFSpeechURLRecognitionRequest(url: audioURL)
        request.shouldReportPartialResults = false
        request.requiresOnDeviceRecognition = false
        request.contextualStrings = contextualStrings
        request.addsPunctuation = true
        request.taskHint = .dictation
        
        return try await withCheckedThrowingContinuation { continuation in
            var hasResumed = false
            
            recognitionTask = recognizer.recognitionTask(with: request) { result, error in
                // Prevent multiple resumes which would crash
                guard !hasResumed else { return }
                
                if let error = error {
                    hasResumed = true
                    print("📝 Speech recognition error: \(error.localizedDescription)")
                    continuation.resume(throwing: TranscriptionError.transcriptionFailed)
                    return
                }
                
                if let result = result {
                    print("📝 Got result, isFinal: \(result.isFinal), text length: \(result.bestTranscription.formattedString.count)")
                    if result.isFinal {
                        hasResumed = true
                        continuation.resume(returning: result.bestTranscription.formattedString)
                    }
                }
            }
        }
    }
    
    func startLiveTranscription() async throws -> AsyncStream<String> {
        guard hasPermission() else {
            throw TranscriptionError.permissionDenied
        }
        
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            throw TranscriptionError.recognizerNotAvailable
        }
        
        // Stop any existing transcription
        await stopLiveTranscription()
        
        // Reset chunking state
        accumulatedTranscript = ""
        currentChunkTranscript = ""
        currentTaskId = nil
        isRestarting = false
        isTranscriptionActive = true
        cleanUpPreviousTask()
        
        // Create audio engine
        let audioEngine = AVAudioEngine()
        self.audioEngine = audioEngine
        
        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        // Create async stream
        return AsyncStream { continuation in
            self.liveContinuation = continuation
            
            // Install audio tap - this runs continuously across chunk restarts
            inputNode.installTap(onBus: 0, bufferSize: 4096, format: recordingFormat) { [weak self] buffer, _ in
                // Append buffer to current recognition request
                self?.recognitionRequest?.append(buffer)
            }
            
            audioEngine.prepare()
            do {
                try audioEngine.start()
            } catch {
                continuation.finish()
                return
            }
            
            // Start the first recognition chunk
            self.startRecognitionChunk(recognizer: recognizer)
            
            continuation.onTermination = { @Sendable _ in
                Task {
                    await self.stopLiveTranscription()
                }
            }
        }
    }
    
    // MARK: - Chunked Recognition
    
    /// Starts a new recognition chunk, creating a fresh request and task.
    /// Assigns the new request BEFORE ending the old one so the audio tap
    /// never has a gap where buffers are silently dropped.
    private func startRecognitionChunk(
        recognizer: SFSpeechRecognizer,
        previousPartial: String = ""
    ) {
        guard isTranscriptionActive else { return }
        
        // Clean up any still-pending previous task before starting a new handover
        previousTaskCleanupTask?.cancel()
        previousTaskCleanupTask = nil
        previousTaskId = nil
        previousChunkSavedTranscript = nil
        
        let oldTask = recognitionTask
        let oldRequest = recognitionRequest
        let oldTaskId = currentTaskId
        
        // Generate new task ID to track this specific task
        let taskId = UUID()
        currentTaskId = taskId
        
        // Create and assign new request FIRST so the audio tap feeds it immediately
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.contextualStrings = contextualStrings
        request.addsPunctuation = true
        request.taskHint = .dictation
        self.recognitionRequest = request
        
        // Start new recognition task
        recognitionTask = recognizer.recognitionTask(with: request) { [weak self, taskId] result, error in
            guard let self = self else { return }
            
            Task {
                await self.handleRecognitionResult(
                    result: result,
                    error: error,
                    recognizer: recognizer,
                    taskId: taskId
                )
            }
        }
        
        // Let the old task settle gracefully instead of cancelling immediately.
        // endAudio() tells the recognizer to finish processing buffered audio and
        // deliver a final result, which may contain words not yet in the last partial.
        oldRequest?.endAudio()
        
        if let oldTaskId, oldTask != nil {
            previousTaskId = oldTaskId
            previousChunkSavedTranscript = previousPartial
            
            previousTaskCleanupTask = Task { [weak self] in
                do {
                    try await Task.sleep(nanoseconds: 2_000_000_000)
                    await self?.cleanUpPreviousTask()
                } catch {}
            }
        }
        
        // Schedule proactive restart before hitting the 60s limit
        scheduleChunkRestart(recognizer: recognizer)
    }
    
    /// Handles recognition results and manages transcript accumulation
    private func handleRecognitionResult(
        result: SFSpeechRecognitionResult?,
        error: Error?,
        recognizer: SFSpeechRecognizer,
        taskId: UUID
    ) {
        guard isTranscriptionActive else { return }
        
        // Handle final results from the previous settling task
        if taskId == previousTaskId {
            if let result = result, result.isFinal {
                handlePreviousChunkFinal(
                    result.bestTranscription.formattedString
                )
            }
            return
        }
        
        guard taskId == currentTaskId else { return }
        
        if let result = result {
            let rawPartial = result.bestTranscription.formattedString
            let currentPartial = removeConsecutiveDuplicates(rawPartial)
            
            currentChunkTranscript = currentPartial
            
            let fullTranscript: String
            if accumulatedTranscript.isEmpty {
                fullTranscript = currentPartial
            } else {
                fullTranscript = accumulatedTranscript + " " + currentPartial
            }
            
            liveContinuation?.yield(fullTranscript)
            
            if result.isFinal {
                appendWithOverlapDetection(currentPartial)
                currentChunkTranscript = ""
                restartRecognitionChunk(recognizer: recognizer)
            }
        }
        
        if error != nil && isTranscriptionActive && !isRestarting {
            restartRecognitionChunk(recognizer: recognizer)
        }
    }
    
    /// When the previous chunk's recognizer finishes settling, its final result
    /// may contain extra words beyond the partial we already committed. Append them.
    private func handlePreviousChunkFinal(_ finalText: String) {
        guard let savedPartial = previousChunkSavedTranscript else {
            cleanUpPreviousTask()
            return
        }
        
        let savedWords = savedPartial.split(separator: " ")
        let finalWords = finalText.split(separator: " ")
        
        if finalWords.count > savedWords.count {
            let extraText = finalWords
                .suffix(from: savedWords.count)
                .joined(separator: " ")
            if !extraText.isEmpty {
                accumulatedTranscript += " " + extraText
                yieldCurrentFullTranscript()
            }
        }
        
        cleanUpPreviousTask()
    }
    
    private func cleanUpPreviousTask() {
        previousTaskCleanupTask?.cancel()
        previousTaskCleanupTask = nil
        previousTaskId = nil
        previousChunkSavedTranscript = nil
    }
    
    /// Yields the full transcript (accumulated + current chunk partial) to the stream
    private func yieldCurrentFullTranscript() {
        let fullTranscript: String
        if accumulatedTranscript.isEmpty {
            fullTranscript = currentChunkTranscript
        } else if currentChunkTranscript.isEmpty {
            fullTranscript = accumulatedTranscript
        } else {
            fullTranscript = accumulatedTranscript + " " + currentChunkTranscript
        }
        liveContinuation?.yield(fullTranscript)
    }
    
    /// Schedules a proactive restart before hitting the 60s limit
    private func scheduleChunkRestart(recognizer: SFSpeechRecognizer) {
        // Cancel any existing restart task
        chunkRestartTask?.cancel()
        
        // Schedule restart after chunkDuration seconds
        chunkRestartTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: UInt64(self?.chunkDuration ?? 50.0) * 1_000_000_000)
                await self?.restartRecognitionChunk(recognizer: recognizer)
            } catch {
                // Task was cancelled, no action needed
            }
        }
    }
    
    /// Restarts recognition by saving current transcript and starting a new chunk
    private func restartRecognitionChunk(recognizer: SFSpeechRecognizer) {
        guard isTranscriptionActive && !isRestarting else { return }
        
        isRestarting = true
        
        // Cancel the scheduled restart task since we're restarting now
        chunkRestartTask?.cancel()
        chunkRestartTask = nil
        
        // Capture the partial before clearing so settlement can compare against it
        let savedPartialForSettlement = currentChunkTranscript
        
        if !currentChunkTranscript.isEmpty {
            appendWithOverlapDetection(currentChunkTranscript)
            currentChunkTranscript = ""
        }
        
        startRecognitionChunk(
            recognizer: recognizer,
            previousPartial: savedPartialForSettlement
        )
        
        isRestarting = false
    }
    
    /// Appends new text to accumulatedTranscript, stripping overlapping words at the boundary
    private func appendWithOverlapDetection(_ newText: String) {
        guard !newText.isEmpty else { return }
        guard !accumulatedTranscript.isEmpty else {
            accumulatedTranscript = newText
            return
        }
        
        let existingWords = accumulatedTranscript.split(separator: " ").map(String.init)
        let newWords = newText.split(separator: " ").map(String.init)
        
        let maxOverlap = min(3, existingWords.count, newWords.count)
        var overlapCount = 0
        
        for length in stride(from: maxOverlap, through: 2, by: -1) {
            let tail = existingWords.suffix(length)
            let head = newWords.prefix(length)
            if Array(tail).map({ $0.lowercased() }) == Array(head).map({ $0.lowercased() }) {
                overlapCount = length
                break
            }
        }
        
        let deduped = newWords.dropFirst(overlapCount).joined(separator: " ")
        if !deduped.isEmpty {
            accumulatedTranscript += " " + removeConsecutiveDuplicates(deduped)
        }
    }
    
    /// Strips consecutive duplicate words and 2-word phrases caused by recognizer stutter.
    /// e.g. "Pinterest Pinterest Pinterest he" → "Pinterest he"
    /// e.g. "life life of control control" → "life of control"
    private func removeConsecutiveDuplicates(_ text: String) -> String {
        let words = text.split(separator: " ").map(String.init)
        guard words.count >= 2 else { return text }
        
        var result: [String] = [words[0]]
        var i = 1
        while i < words.count {
            if i + 1 < words.count,
               result.count >= 2,
               result[result.count - 2].lowercased() == words[i].lowercased(),
               result[result.count - 1].lowercased() == words[i + 1].lowercased() {
                i += 2
                continue
            }
            if words[i].lowercased() == result.last?.lowercased() {
                i += 1
                continue
            }
            result.append(words[i])
            i += 1
        }
        return result.joined(separator: " ")
    }
    
    func stopLiveTranscription() async {
        // Prevent chunk restarts during shutdown
        chunkRestartTask?.cancel()
        chunkRestartTask = nil
        isRestarting = true
        
        cleanUpPreviousTask()
        
        // Stop the audio engine so no new audio arrives
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        
        // Signal the recognizer to finish processing any buffered audio.
        // Keep isTranscriptionActive true briefly so handleRecognitionResult
        // can still process the final result and yield it to the stream.
        recognitionRequest?.endAudio()
        
        // Give the recognizer up to 1.5s to deliver its final result
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        
        // Commit any remaining partial transcript
        if !currentChunkTranscript.isEmpty {
            appendWithOverlapDetection(currentChunkTranscript)
            currentChunkTranscript = ""
        }
        
        // Yield final accumulated transcript before closing the stream
        if !accumulatedTranscript.isEmpty {
            liveContinuation?.yield(accumulatedTranscript)
        }
        
        // Now fully shut down
        isTranscriptionActive = false
        isRestarting = false
        
        recognitionTask?.cancel()
        
        audioEngine = nil
        recognitionRequest = nil
        recognitionTask = nil
        
        liveContinuation?.finish()
        liveContinuation = nil
        
        accumulatedTranscript = ""
        currentChunkTranscript = ""
        currentTaskId = nil

        // Do not deactivate audio session here; recording service owns it.
    }
    
    nonisolated func isAvailable() -> Bool {
        guard let recognizer = speechRecognizer else { return false }
        return recognizer.isAvailable
    }
}

// MARK: - Mock Implementation

actor MockTranscriptionService: TranscriptionService {
    var shouldGrantPermission = true
    var shouldFailTranscription = false
    var mockTranscript = "This is a mock transcription of the audio recording."
    
    func requestPermission() async -> Bool {
        return shouldGrantPermission
    }
    
    nonisolated func hasPermission() -> Bool {
        return true
    }
    
    func transcribe(audioURL: URL) async throws -> String {
        guard !shouldFailTranscription else {
            throw TranscriptionError.transcriptionFailed
        }
        
        // Simulate processing time
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        return mockTranscript
    }
    
    func startLiveTranscription() async throws -> AsyncStream<String> {
        return AsyncStream { continuation in
            Task {
                let words = mockTranscript.components(separatedBy: " ")
                var accumulated = ""
                
                for word in words {
                    try? await Task.sleep(nanoseconds: 200_000_000)
                    accumulated += (accumulated.isEmpty ? "" : " ") + word
                    continuation.yield(accumulated)
                }
                
                continuation.finish()
            }
        }
    }
    
    func stopLiveTranscription() async {
        // No-op for mock
    }
    
    nonisolated func isAvailable() -> Bool {
        return true
    }
}
