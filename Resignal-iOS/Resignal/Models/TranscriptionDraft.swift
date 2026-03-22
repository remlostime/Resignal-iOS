//
//  TranscriptionDraft.swift
//  Resignal
//
//  Represents a pending or failed transcription that can be retried.
//  Persisted as a JSON sidecar alongside the cached audio file.
//

import Foundation

struct TranscriptionDraft: Codable, Sendable, Identifiable {
    let id: UUID
    let recordingId: UUID
    let createdAt: Date
    var status: DraftStatus
    var lastError: String?
    var jobId: String?
    var partialTranscript: String?

    enum DraftStatus: String, Codable, Sendable {
        case pending
        case uploading
        case processing
        case failed
        case completed
    }
}
