//
//  SessionAttachment.swift
//  Resignal
//
//  Model for file and image attachments associated with sessions.
//

import Foundation
import SwiftData

/// Types of attachments that can be added to sessions
enum AttachmentType: String, Codable, Sendable {
    case image
    case file
}

/// Represents a file or image attachment for a session
@Model
final class SessionAttachment {
    
    // MARK: - Properties
    
    @Attribute(.unique) var id: UUID
    var type: String
    var fileURL: String
    var filename: String
    var thumbnailURL: String?
    var createdAt: Date
    var fileSize: Int64
    
    // MARK: - Initialization
    
    init(
        id: UUID = UUID(),
        type: AttachmentType,
        fileURL: URL,
        filename: String,
        thumbnailURL: URL? = nil,
        createdAt: Date = Date(),
        fileSize: Int64 = 0
    ) {
        self.id = id
        self.type = type.rawValue
        self.fileURL = fileURL.path
        self.filename = filename
        self.thumbnailURL = thumbnailURL?.path
        self.createdAt = createdAt
        self.fileSize = fileSize
    }
    
    // MARK: - Computed Properties
    
    /// Returns the attachment type as an enum
    var attachmentType: AttachmentType {
        get { AttachmentType(rawValue: type) ?? .file }
        set { type = newValue.rawValue }
    }
    
    /// Returns the file URL as a URL object
    var url: URL {
        URL(fileURLWithPath: fileURL)
    }
    
    /// Returns the thumbnail URL as a URL object if available
    var thumbnail: URL? {
        guard let thumbnailURL = thumbnailURL else { return nil }
        return URL(fileURLWithPath: thumbnailURL)
    }
    
    /// Returns a human-readable file size string
    var fileSizeFormatted: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }
}

// MARK: - Sample Data

extension SessionAttachment {
    static var sampleImage: SessionAttachment {
        SessionAttachment(
            type: .image,
            fileURL: URL(fileURLWithPath: "/tmp/sample.jpg"),
            filename: "sample.jpg",
            fileSize: 1024 * 500 // 500 KB
        )
    }
    
    static var sampleFile: SessionAttachment {
        SessionAttachment(
            type: .file,
            fileURL: URL(fileURLWithPath: "/tmp/resume.pdf"),
            filename: "resume.pdf",
            fileSize: 1024 * 1024 * 2 // 2 MB
        )
    }
}
