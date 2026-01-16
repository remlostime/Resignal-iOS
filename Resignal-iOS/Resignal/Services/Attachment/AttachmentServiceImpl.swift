//
//  AttachmentServiceImpl.swift
//  Resignal
//
//  Implementation of attachment management service.
//

import Foundation
import UIKit

/// Implementation of AttachmentService
actor AttachmentServiceImpl: AttachmentService {
    
    // MARK: - Properties
    
    static let maxFileSize: Int64 = 10 * 1024 * 1024 // 10 MB
    
    private let fileManager = FileManager.default
    private let attachmentsDirectory: URL
    
    // MARK: - Initialization
    
    init() {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.attachmentsDirectory = documentsPath.appendingPathComponent("Attachments", isDirectory: true)
        
        // Create attachments directory if it doesn't exist
        try? fileManager.createDirectory(at: attachmentsDirectory, withIntermediateDirectories: true)
    }
    
    // MARK: - AttachmentService Implementation
    
    func saveImage(_ image: UIImage, filename: String) async throws -> SessionAttachment {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw AttachmentError.invalidData
        }
        
        guard Int64(imageData.count) <= Self.maxFileSize else {
            throw AttachmentError.fileSizeTooLarge
        }
        
        let fileURL = attachmentsDirectory.appendingPathComponent("\(UUID().uuidString)_\(filename)")
        
        do {
            try imageData.write(to: fileURL)
        } catch {
            throw AttachmentError.saveFailed
        }
        
        // Generate thumbnail
        let thumbnail = await generateThumbnail(for: image, maxSize: CGSize(width: 200, height: 200))
        let thumbnailURL = attachmentsDirectory.appendingPathComponent("thumb_\(fileURL.lastPathComponent)")
        
        if let thumbnailData = thumbnail.jpegData(compressionQuality: 0.7) {
            try? thumbnailData.write(to: thumbnailURL)
        }
        
        return SessionAttachment(
            type: .image,
            fileURL: fileURL,
            filename: filename,
            thumbnailURL: thumbnailURL,
            fileSize: Int64(imageData.count)
        )
    }
    
    func saveFile(data: Data, filename: String, type: AttachmentType) async throws -> SessionAttachment {
        guard Int64(data.count) <= Self.maxFileSize else {
            throw AttachmentError.fileSizeTooLarge
        }
        
        let fileURL = attachmentsDirectory.appendingPathComponent("\(UUID().uuidString)_\(filename)")
        
        do {
            try data.write(to: fileURL)
        } catch {
            throw AttachmentError.saveFailed
        }
        
        return SessionAttachment(
            type: type,
            fileURL: fileURL,
            filename: filename,
            fileSize: Int64(data.count)
        )
    }
    
    func saveFile(from url: URL, type: AttachmentType) async throws -> SessionAttachment {
        guard fileManager.fileExists(atPath: url.path) else {
            throw AttachmentError.fileNotFound
        }
        
        let data = try Data(contentsOf: url)
        return try await saveFile(data: data, filename: url.lastPathComponent, type: type)
    }
    
    func loadAttachment(_ attachment: SessionAttachment) async throws -> Data {
        let fileURL = attachment.url
        
        guard fileManager.fileExists(atPath: fileURL.path) else {
            throw AttachmentError.fileNotFound
        }
        
        do {
            return try Data(contentsOf: fileURL)
        } catch {
            throw AttachmentError.fileNotFound
        }
    }
    
    func loadImage(_ attachment: SessionAttachment) async throws -> UIImage {
        let data = try await loadAttachment(attachment)
        
        guard let image = UIImage(data: data) else {
            throw AttachmentError.invalidData
        }
        
        return image
    }
    
    func deleteAttachment(_ attachment: SessionAttachment) async throws {
        let fileURL = attachment.url
        
        do {
            if fileManager.fileExists(atPath: fileURL.path) {
                try fileManager.removeItem(at: fileURL)
            }
            
            // Delete thumbnail if exists
            if let thumbnailURL = attachment.thumbnail {
                if fileManager.fileExists(atPath: thumbnailURL.path) {
                    try? fileManager.removeItem(at: thumbnailURL)
                }
            }
        } catch {
            throw AttachmentError.deleteFailed
        }
    }
    
    func deleteAttachments(_ attachments: [SessionAttachment]) async throws {
        for attachment in attachments {
            try await deleteAttachment(attachment)
        }
    }
    
    func generateThumbnail(for image: UIImage, maxSize: CGSize) async -> UIImage {
        let size = image.size
        let widthRatio = maxSize.width / size.width
        let heightRatio = maxSize.height / size.height
        let ratio = min(widthRatio, heightRatio)
        
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
    
    func getBase64Data(_ attachment: SessionAttachment) async throws -> String {
        let data = try await loadAttachment(attachment)
        return data.base64EncodedString()
    }
}

// MARK: - Mock Implementation

actor MockAttachmentService: AttachmentService {
    static let maxFileSize: Int64 = 10 * 1024 * 1024
    
    var shouldFailSave = false
    var shouldFailLoad = false
    
    func saveImage(_ image: UIImage, filename: String) async throws -> SessionAttachment {
        guard !shouldFailSave else {
            throw AttachmentError.saveFailed
        }
        
        return SessionAttachment(
            type: .image,
            fileURL: URL(fileURLWithPath: "/tmp/mock_\(filename)"),
            filename: filename,
            fileSize: 1024 * 500
        )
    }
    
    func saveFile(data: Data, filename: String, type: AttachmentType) async throws -> SessionAttachment {
        guard !shouldFailSave else {
            throw AttachmentError.saveFailed
        }
        
        return SessionAttachment(
            type: type,
            fileURL: URL(fileURLWithPath: "/tmp/mock_\(filename)"),
            filename: filename,
            fileSize: Int64(data.count)
        )
    }
    
    func saveFile(from url: URL, type: AttachmentType) async throws -> SessionAttachment {
        guard !shouldFailSave else {
            throw AttachmentError.saveFailed
        }
        
        return SessionAttachment(
            type: type,
            fileURL: url,
            filename: url.lastPathComponent,
            fileSize: 1024 * 1024
        )
    }
    
    func loadAttachment(_ attachment: SessionAttachment) async throws -> Data {
        guard !shouldFailLoad else {
            throw AttachmentError.fileNotFound
        }
        
        return Data()
    }
    
    func loadImage(_ attachment: SessionAttachment) async throws -> UIImage {
        guard !shouldFailLoad else {
            throw AttachmentError.fileNotFound
        }
        
        return UIImage()
    }
    
    func deleteAttachment(_ attachment: SessionAttachment) async throws {
        // No-op for mock
    }
    
    func deleteAttachments(_ attachments: [SessionAttachment]) async throws {
        // No-op for mock
    }
    
    func generateThumbnail(for image: UIImage, maxSize: CGSize) async -> UIImage {
        return image
    }
    
    func getBase64Data(_ attachment: SessionAttachment) async throws -> String {
        return "mock_base64_data"
    }
}
