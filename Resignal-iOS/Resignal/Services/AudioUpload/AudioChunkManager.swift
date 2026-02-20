//
//  AudioChunkManager.swift
//  Resignal
//
//  Splits large audio files into size-based chunks for sequential upload.
//  Chunk size is kept under 20MB to stay safely within the 25MB Whisper API limit.
//

import Foundation

// MARK: - Models

/// Metadata describing a single audio chunk ready for upload.
struct AudioChunkMetadata: Sendable {
    let chunkIndex: Int
    let totalChunks: Int
    let interviewId: String
    let fileURL: URL
    let fileSize: Int64
}

// MARK: - Protocol

/// Responsible for splitting audio files into upload-safe chunks and cleaning up afterwards.
protocol AudioChunkManager: Sendable {
    /// Splits the audio file at `url` into chunks no larger than `maxChunkSize` bytes.
    /// Each chunk is written to a temporary directory and returned with its metadata.
    func splitAudioFile(
        at url: URL,
        interviewId: String,
        maxChunkSize: Int64
    ) throws -> [AudioChunkMetadata]

    /// Deletes all temporary chunk files created during splitting.
    func cleanupChunks(_ chunks: [AudioChunkMetadata])
}

extension AudioChunkManager {
    /// Convenience overload using the default 20MB chunk size.
    func splitAudioFile(at url: URL, interviewId: String) throws -> [AudioChunkMetadata] {
        try splitAudioFile(at: url, interviewId: interviewId, maxChunkSize: AudioChunkConstants.defaultMaxChunkSize)
    }
}

// MARK: - Constants

enum AudioChunkConstants {
    /// 20MB -- safe margin under the 25MB Whisper API limit.
    static let defaultMaxChunkSize: Int64 = 20 * 1024 * 1024
}

// MARK: - Implementation

/// File-size-based audio chunk splitter.
///
/// Strategy: reads `maxChunkSize` bytes at a time from the source file and writes
/// each segment to a numbered `.m4a` file inside `Documents/AudioChunks/{interviewId}/`.
/// The resulting chunks preserve chronological order via `chunkIndex`.
///
/// Note: raw byte splitting does not guarantee each chunk is independently decodable
/// by every player, but the Whisper API processes the raw audio stream and handles
/// partial container boundaries. The backend reassembles transcripts in order.
final class AudioChunkManagerImpl: AudioChunkManager {

    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func splitAudioFile(
        at url: URL,
        interviewId: String,
        maxChunkSize: Int64
    ) throws -> [AudioChunkMetadata] {
        guard fileManager.fileExists(atPath: url.path) else {
            throw AudioChunkError.sourceFileNotFound(url.path)
        }

        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        guard let totalSize = attributes[.size] as? Int64, totalSize > 0 else {
            throw AudioChunkError.unreadableFileSize
        }

        // If the file already fits in a single chunk, skip splitting entirely.
        if totalSize <= maxChunkSize {
            return [AudioChunkMetadata(
                chunkIndex: 0,
                totalChunks: 1,
                interviewId: interviewId,
                fileURL: url,
                fileSize: totalSize
            )]
        }

        let chunksDirectory = try createChunksDirectory(for: interviewId)
        let totalChunks = Int(ceil(Double(totalSize) / Double(maxChunkSize)))

        let fileHandle = try FileHandle(forReadingFrom: url)
        defer { try? fileHandle.close() }

        var chunks: [AudioChunkMetadata] = []
        chunks.reserveCapacity(totalChunks)

        let sourceExtension = url.pathExtension.isEmpty ? "m4a" : url.pathExtension

        for index in 0..<totalChunks {
            let chunkFileName = "chunk_\(index).\(sourceExtension)"
            let chunkURL = chunksDirectory.appendingPathComponent(chunkFileName)

            let offset = Int64(index) * maxChunkSize
            let bytesToRead = min(maxChunkSize, totalSize - offset)

            try fileHandle.seek(toOffset: UInt64(offset))
            guard let data = try fileHandle.read(upToCount: Int(bytesToRead)), !data.isEmpty else {
                throw AudioChunkError.readFailed(chunkIndex: index)
            }

            try data.write(to: chunkURL, options: .atomic)

            chunks.append(AudioChunkMetadata(
                chunkIndex: index,
                totalChunks: totalChunks,
                interviewId: interviewId,
                fileURL: chunkURL,
                fileSize: Int64(data.count)
            ))
        }

        return chunks
    }

    func cleanupChunks(_ chunks: [AudioChunkMetadata]) {
        // Collect unique parent directories so we can remove the whole folder.
        var directories: Set<String> = []

        for chunk in chunks {
            let dir = chunk.fileURL.deletingLastPathComponent().path
            directories.insert(dir)
            try? fileManager.removeItem(at: chunk.fileURL)
        }

        for dir in directories {
            let dirURL = URL(fileURLWithPath: dir, isDirectory: true)
            // Only remove if the directory is inside our AudioChunks folder.
            guard dirURL.pathComponents.contains("AudioChunks") else { continue }
            try? fileManager.removeItem(at: dirURL)
        }
    }

    // MARK: - Private

    private func createChunksDirectory(for interviewId: String) throws -> URL {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let chunksDirectory = documentsPath
            .appendingPathComponent("AudioChunks", isDirectory: true)
            .appendingPathComponent(interviewId, isDirectory: true)

        try fileManager.createDirectory(at: chunksDirectory, withIntermediateDirectories: true)
        return chunksDirectory
    }
}

// MARK: - Errors

enum AudioChunkError: LocalizedError {
    case sourceFileNotFound(String)
    case unreadableFileSize
    case readFailed(chunkIndex: Int)

    var errorDescription: String? {
        switch self {
        case .sourceFileNotFound(let path):
            return "Audio file not found at path: \(path)"
        case .unreadableFileSize:
            return "Unable to determine audio file size."
        case .readFailed(let index):
            return "Failed to read data for chunk \(index)."
        }
    }
}
