//
//  TranscriptionService.swift
//  Resignal
//
//  Protocol defining speech-to-text transcription capabilities.
//

import Foundation
import Speech

/// Errors that can occur during transcription
enum TranscriptionError: LocalizedError {
    case permissionDenied
    case recognizerNotAvailable
    case transcriptionFailed
    case audioFileNotFound
    case unsupportedLocale
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Speech recognition permission is required to transcribe audio."
        case .recognizerNotAvailable:
            return "Speech recognizer is not available for this device or locale."
        case .transcriptionFailed:
            return "Failed to transcribe audio. Please try again."
        case .audioFileNotFound:
            return "Audio file not found."
        case .unsupportedLocale:
            return "The selected language is not supported for transcription."
        }
    }
}

/// Protocol defining speech-to-text transcription capabilities
protocol TranscriptionService: Actor {
    /// Request speech recognition permission
    func requestPermission() async -> Bool
    
    /// Check if speech recognition permission is granted
    func hasPermission() -> Bool
    
    /// Transcribe an audio file to text
    func transcribe(audioURL: URL) async throws -> String
    
    /// Start live transcription (returns async stream of partial results)
    func startLiveTranscription() async throws -> AsyncStream<String>
    
    /// Stop live transcription
    func stopLiveTranscription() async
    
    /// Check if speech recognition is available for the device
    func isAvailable() -> Bool
}
