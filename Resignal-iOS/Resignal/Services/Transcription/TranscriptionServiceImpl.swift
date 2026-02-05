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
    private let chunkDuration: TimeInterval = 50.0
    /// Flag to track if transcription is actively running
    private var isTranscriptionActive: Bool = false
    /// Unique identifier for the current recognition task (to ignore stale callbacks)
    private var currentTaskId: UUID?
    
    // MARK: - Initialization
    
    init(locale: Locale = .current) {
        self.speechRecognizer = SFSpeechRecognizer(locale: locale)
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
        
        // Create audio engine
        let audioEngine = AVAudioEngine()
        self.audioEngine = audioEngine
        
        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        // Create async stream
        return AsyncStream { continuation in
            self.liveContinuation = continuation
            
            // Install audio tap - this runs continuously across chunk restarts
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
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
    
    /// Starts a new recognition chunk, creating a fresh request and task
    private func startRecognitionChunk(recognizer: SFSpeechRecognizer) {
        guard isTranscriptionActive else { return }
        
        // Cancel previous task if exists
        recognitionTask?.cancel()
        recognitionRequest?.endAudio()
        
        // Generate new task ID to track this specific task
        let taskId = UUID()
        currentTaskId = taskId
        
        // Create new recognition request
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        self.recognitionRequest = request
        
        // Start new recognition task
        recognitionTask = recognizer.recognitionTask(with: request) { [weak self, taskId] result, error in
            guard let self = self else { return }
            
            Task {
                await self.handleRecognitionResult(result: result, error: error, recognizer: recognizer, taskId: taskId)
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
        // Ignore callbacks from old/cancelled tasks
        guard taskId == currentTaskId else { return }
        guard isTranscriptionActive else { return }
        
        if let result = result {
            let currentPartial = result.bestTranscription.formattedString
            
            // Track the current chunk's partial transcript for proactive restarts
            currentChunkTranscript = currentPartial
            
            // Combine accumulated transcript with current partial result
            let fullTranscript: String
            if accumulatedTranscript.isEmpty {
                fullTranscript = currentPartial
            } else {
                fullTranscript = accumulatedTranscript + " " + currentPartial
            }
            
            // Yield the combined transcript
            liveContinuation?.yield(fullTranscript)
            
            // When chunk completes naturally (isFinal), save and restart
            if result.isFinal {
                accumulatedTranscript = fullTranscript
                currentChunkTranscript = ""
                restartRecognitionChunk(recognizer: recognizer)
            }
        }
        
        // Handle errors by attempting restart (unless stopping)
        if error != nil && isTranscriptionActive && !isRestarting {
            restartRecognitionChunk(recognizer: recognizer)
        }
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
        
        // Save the current chunk's transcript before restarting
        // This preserves text when proactively restarting (before isFinal)
        if !currentChunkTranscript.isEmpty {
            if accumulatedTranscript.isEmpty {
                accumulatedTranscript = currentChunkTranscript
            } else {
                accumulatedTranscript = accumulatedTranscript + " " + currentChunkTranscript
            }
            currentChunkTranscript = ""
        }
        
        // Start a new recognition chunk
        startRecognitionChunk(recognizer: recognizer)
        
        isRestarting = false
    }
    
    func stopLiveTranscription() async {
        // Mark transcription as inactive to prevent restarts
        isTranscriptionActive = false
        isRestarting = false
        
        // Cancel the chunk restart task
        chunkRestartTask?.cancel()
        chunkRestartTask = nil
        
        // Stop audio engine and remove tap
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        
        // End recognition request and cancel task
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        
        // Clean up references
        audioEngine = nil
        recognitionRequest = nil
        recognitionTask = nil
        
        // Finish the continuation stream
        liveContinuation?.finish()
        liveContinuation = nil
        
        // Reset transcript and task state
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
