//
//  AudioCacheService.swift
//  Resignal
//
//  Disk-backed cache for audio recordings awaiting transcription.
//  Audio files are retained until the user sees a successful transcript,
//  enabling retry on Whisper API failure and draft recovery after app relaunch.
//

import Foundation

// MARK: - Protocol

protocol AudioCacheService: Sendable {
    /// Copies the recording into a stable cache location. Returns the cached URL.
    func cacheRecording(from sourceURL: URL, recordingId: UUID) throws -> URL

    /// Returns the cached audio URL for a given recording ID, if it still exists on disk.
    func cachedURL(for recordingId: UUID) -> URL?

    /// Removes both the audio file and its draft sidecar for a given recording.
    func evict(recordingId: UUID)

    /// Removes all cached audio files and drafts.
    func evictAll()

    // MARK: - Draft persistence

    func saveDraft(_ draft: TranscriptionDraft) throws
    func loadDraft(for recordingId: UUID) -> TranscriptionDraft?
    func allDrafts() -> [TranscriptionDraft]
    func deleteDraft(for recordingId: UUID)

    // MARK: - Storage metrics

    /// Total bytes consumed by the cache directory.
    func totalCacheSize() -> Int64
}

// MARK: - Implementation

actor AudioCacheServiceImpl: AudioCacheService {

    private let fileManager: FileManager
    private let cacheDirectory: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private static let staleDraftAge: TimeInterval = 7 * 24 * 60 * 60 // 7 days

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager

        let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.cacheDirectory = documents.appendingPathComponent("AudioCache", isDirectory: true)

        ensureCacheDirectory()
        evictStaleDrafts()
    }

    // MARK: - AudioCacheService

    func cacheRecording(from sourceURL: URL, recordingId: UUID) throws -> URL {
        let ext = sourceURL.pathExtension.isEmpty ? "m4a" : sourceURL.pathExtension
        let destination = cacheDirectory.appendingPathComponent("\(recordingId.uuidString).\(ext)")

        if fileManager.fileExists(atPath: destination.path) {
            try? fileManager.removeItem(at: destination)
        }
        try fileManager.copyItem(at: sourceURL, to: destination)
        return destination
    }

    func cachedURL(for recordingId: UUID) -> URL? {
        let m4a = cacheDirectory.appendingPathComponent("\(recordingId.uuidString).m4a")
        if fileManager.fileExists(atPath: m4a.path) { return m4a }
        return nil
    }

    func evict(recordingId: UUID) {
        let prefix = recordingId.uuidString
        removeFiles(matching: prefix)
    }

    func evictAll() {
        guard let contents = try? fileManager.contentsOfDirectory(
            at: cacheDirectory, includingPropertiesForKeys: nil
        ) else { return }
        for url in contents {
            try? fileManager.removeItem(at: url)
        }
    }

    // MARK: - Draft persistence

    func saveDraft(_ draft: TranscriptionDraft) throws {
        let url = draftURL(for: draft.recordingId)
        let data = try encoder.encode(draft)
        try data.write(to: url, options: .atomic)
    }

    func loadDraft(for recordingId: UUID) -> TranscriptionDraft? {
        let url = draftURL(for: recordingId)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(TranscriptionDraft.self, from: data)
    }

    func allDrafts() -> [TranscriptionDraft] {
        guard let contents = try? fileManager.contentsOfDirectory(
            at: cacheDirectory, includingPropertiesForKeys: nil
        ) else { return [] }

        return contents
            .filter { $0.pathExtension == "json" }
            .compactMap { url -> TranscriptionDraft? in
                guard let data = try? Data(contentsOf: url) else { return nil }
                return try? decoder.decode(TranscriptionDraft.self, from: data)
            }
    }

    func deleteDraft(for recordingId: UUID) {
        try? fileManager.removeItem(at: draftURL(for: recordingId))
    }

    // MARK: - Storage metrics

    func totalCacheSize() -> Int64 {
        guard let contents = try? fileManager.contentsOfDirectory(
            at: cacheDirectory,
            includingPropertiesForKeys: [.fileSizeKey]
        ) else { return 0 }

        return contents.reduce(into: Int64(0)) { total, url in
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
            total += Int64(size)
        }
    }

    // MARK: - Private

    private func ensureCacheDirectory() {
        if !fileManager.fileExists(atPath: cacheDirectory.path) {
            try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        }
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        var mutableURL = cacheDirectory
        try? mutableURL.setResourceValues(resourceValues)
    }

    private func draftURL(for recordingId: UUID) -> URL {
        cacheDirectory.appendingPathComponent("\(recordingId.uuidString).draft.json")
    }

    private func removeFiles(matching prefix: String) {
        guard let contents = try? fileManager.contentsOfDirectory(
            at: cacheDirectory, includingPropertiesForKeys: nil
        ) else { return }
        for url in contents where url.lastPathComponent.hasPrefix(prefix) {
            try? fileManager.removeItem(at: url)
        }
    }

    private func evictStaleDrafts() {
        let cutoff = Date().addingTimeInterval(-Self.staleDraftAge)
        for draft in allDrafts() where draft.createdAt < cutoff {
            evict(recordingId: draft.recordingId)
        }
    }
}

// MARK: - Mock

actor MockAudioCacheService: AudioCacheService {

    private var recordings: [UUID: URL] = [:]
    private var drafts: [UUID: TranscriptionDraft] = [:]

    func cacheRecording(from sourceURL: URL, recordingId: UUID) throws -> URL {
        recordings[recordingId] = sourceURL
        return sourceURL
    }

    func cachedURL(for recordingId: UUID) -> URL? {
        recordings[recordingId]
    }

    func evict(recordingId: UUID) {
        recordings.removeValue(forKey: recordingId)
        drafts.removeValue(forKey: recordingId)
    }

    func evictAll() {
        recordings.removeAll()
        drafts.removeAll()
    }

    func saveDraft(_ draft: TranscriptionDraft) throws {
        drafts[draft.recordingId] = draft
    }

    func loadDraft(for recordingId: UUID) -> TranscriptionDraft? {
        drafts[recordingId]
    }

    func allDrafts() -> [TranscriptionDraft] {
        Array(drafts.values)
    }

    func deleteDraft(for recordingId: UUID) {
        drafts.removeValue(forKey: recordingId)
    }

    func totalCacheSize() -> Int64 { 0 }
}
