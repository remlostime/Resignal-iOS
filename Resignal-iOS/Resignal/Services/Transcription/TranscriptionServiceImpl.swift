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
        
        let request = SFSpeechURLRecognitionRequest(url: audioURL)
        request.shouldReportPartialResults = false
        request.requiresOnDeviceRecognition = false
        
        return try await withCheckedThrowingContinuation { continuation in
            recognitionTask = recognizer.recognitionTask(with: request) { result, error in
                if let error = error {
                    continuation.resume(throwing: TranscriptionError.transcriptionFailed)
                    return
                }
                
                if let result = result, result.isFinal {
                    continuation.resume(returning: result.bestTranscription.formattedString)
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
        
        // Create audio engine and request
        let audioEngine = AVAudioEngine()
        self.audioEngine = audioEngine
        
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        self.recognitionRequest = request
        
        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        // Create async stream
        return AsyncStream { continuation in
            self.liveContinuation = continuation
            
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
                request.append(buffer)
            }
            
            audioEngine.prepare()
            do {
                try audioEngine.start()
            } catch {
                continuation.finish()
                return
            }
            
            self.recognitionTask = recognizer.recognitionTask(with: request) { result, error in
                if let result = result {
                    let transcription = result.bestTranscription.formattedString
                    continuation.yield(transcription)
                    
                    if result.isFinal {
                        continuation.finish()
                    }
                }
                
                if error != nil {
                    continuation.finish()
                }
            }
            
            continuation.onTermination = { @Sendable _ in
                Task {
                    await self.stopLiveTranscription()
                }
            }
        }
    }
    
    func stopLiveTranscription() async {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        
        audioEngine = nil
        recognitionRequest = nil
        recognitionTask = nil
        liveContinuation?.finish()
        liveContinuation = nil
        
        // Deactivate audio session
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
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
