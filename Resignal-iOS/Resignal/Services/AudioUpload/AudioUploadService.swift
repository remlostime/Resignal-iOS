//
//  AudioUploadService.swift
//  Resignal
//
//  Protocol, state enum, and error types for chunked audio upload to the backend.
//  The backend transcribes each chunk via OpenAI Whisper and concatenates results.
//

import Foundation

// MARK: - Upload State

/// Observable state for the chunked upload + server-side transcription pipeline.
enum TranscriptionUploadState: Sendable, Equatable {
    /// No upload in progress.
    case idle
    /// Splitting the recording into chunks.
    case preparing
    /// Uploading chunks. `progress` is 0.0–1.0 reflecting overall upload completion.
    case uploading(progress: Double)
    /// All chunks uploaded; waiting for the server to finish transcription.
    case processing
    /// Server returned the final transcript.
    case completed(transcript: String)
    /// The pipeline failed.
    case failed(errorMessage: String)
}

// MARK: - Errors

enum AudioUploadError: LocalizedError {
    case chunkingFailed(String)
    case uploadFailed(chunkIndex: Int, underlying: Error)
    case jobCreationFailed(String)
    case completionFailed(String)
    case unauthorized
    case fileTooLarge
    case serverError(statusCode: Int, message: String)
    case cancelled
    case invalidResponse
    case pollingTimeout

    var errorDescription: String? {
        switch self {
        case .chunkingFailed(let reason):
            return "Failed to split audio file: \(reason)"
        case .uploadFailed(let index, let underlying):
            return "Failed to upload chunk \(index): \(underlying.localizedDescription)"
        case .jobCreationFailed(let reason):
            return "Failed to create transcription job: \(reason)"
        case .completionFailed(let reason):
            return "Failed to finalize transcription: \(reason)"
        case .unauthorized:
            return "Unauthorized. Please restart the app and try again."
        case .fileTooLarge:
            return "Audio chunk exceeds the server size limit."
        case .serverError(let code, let message):
            return "Server error (\(code)): \(message)"
        case .cancelled:
            return "Upload was cancelled."
        case .invalidResponse:
            return "Received an unexpected response from the server."
        case .pollingTimeout:
            return "Transcription is taking longer than expected. Please try again."
        }
    }
}

// MARK: - Protocol

/// Uploads a recorded audio file to the backend in size-safe chunks,
/// waits for server-side Whisper transcription, and returns the transcript.
protocol AudioUploadService: Actor {
    /// Splits the file, uploads all chunks, optionally calls the completion endpoint,
    /// polls for the transcript, and returns it.
    ///
    /// Pass `nil` for `interviewId` when no backend interview exists yet (e.g. during
    /// initial recording). The completion endpoint is skipped in that case.
    ///
    /// Throws `AudioUploadError` on failure. Supports cooperative cancellation
    /// via `cancel()` (checked between chunks and during polling).
    func uploadInterviewAudio(fileURL: URL, interviewId: String?) async throws -> String

    /// Returns an `AsyncStream` that emits every state transition for the current
    /// (or next) upload. Multiple consumers can each call this to get their own stream.
    func observeState() -> AsyncStream<TranscriptionUploadState>

    /// Cancels the in-flight upload. The next state yielded will be `.failed`.
    func cancel()
}
