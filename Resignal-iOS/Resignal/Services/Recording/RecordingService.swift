//
//  RecordingService.swift
//  Resignal
//
//  Protocol defining audio recording capabilities.
//

import Foundation
import AVFoundation

/// Errors that can occur during recording
enum RecordingError: LocalizedError {
    case permissionDenied
    case recordingFailed
    case audioSessionFailed
    case fileOperationFailed
    case alreadyRecording
    case notRecording
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Microphone permission is required to record audio."
        case .recordingFailed:
            return "Failed to start recording. Please try again."
        case .audioSessionFailed:
            return "Failed to configure audio session."
        case .fileOperationFailed:
            return "Failed to save recording file."
        case .alreadyRecording:
            return "A recording is already in progress."
        case .notRecording:
            return "No active recording to stop."
        }
    }
}

/// Recording state
enum RecordingState: Sendable {
    case idle
    case recording
    case paused
    case processing
}

/// Protocol defining audio recording capabilities
@MainActor
protocol RecordingService {
    /// Current recording state
    var state: RecordingState { get }
    
    /// Current recording duration in seconds
    var duration: TimeInterval { get }
    
    /// Request microphone permission
    func requestPermission() async -> Bool
    
    /// Check if microphone permission is granted
    func hasPermission() -> Bool
    
    /// Start recording audio
    func startRecording() async throws -> URL
    
    /// Stop recording and return the file URL
    func stopRecording() async throws -> URL
    
    /// Pause the current recording
    func pauseRecording() throws
    
    /// Resume a paused recording
    func resumeRecording() throws
    
    /// Cancel and delete the current recording
    func cancelRecording() async throws
    
    /// Get the current audio level (0.0 to 1.0) for visualization
    func getAudioLevel() -> Float
}
