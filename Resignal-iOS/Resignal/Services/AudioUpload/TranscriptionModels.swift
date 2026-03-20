//
//  TranscriptionModels.swift
//  Resignal
//
//  Codable models for the transcription polling API and Blob-hosted result payload.
//

import Foundation

/// Response from `GET /api/transcriptions/:jobId`.
///
/// The endpoint no longer returns transcript data inline. When `status` is
/// `"completed"`, `resultUrl` points to a public Blob CDN JSON file that
/// contains the full transcript and segments.
struct TranscriptionStatusResponse: Decodable, Sendable {
    let success: Bool
    let status: String
    let resultUrl: String?
    let duration: Double?
    let completedChunks: Int
    let totalChunks: Int
}

/// Payload downloaded from the Blob URL returned in `TranscriptionStatusResponse.resultUrl`.
struct TranscriptionResult: Decodable, Sendable {
    let transcript: String
    let segments: [TranscriptionSegment]
    let duration: Double
}

/// A single transcribed segment with timing information.
struct TranscriptionSegment: Decodable, Sendable {
    let id: Int
    let start: Double
    let end: Double
    let text: String
}
