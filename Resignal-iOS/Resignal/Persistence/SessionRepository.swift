//
//  SessionRepository.swift
//  Resignal
//
//  Repository for managing Session persistence with SwiftData.
//

import Foundation
import SwiftData

/// Protocol defining session repository interface
@MainActor
protocol SessionRepositoryProtocol: Sendable {
    func fetchAll() throws -> [Session]
    func fetch(limit: Int, offset: Int) throws -> [Session]
    func fetch(id: UUID) throws -> Session?
    func save(_ session: Session) throws
    func delete(_ session: Session) throws
    func deleteAll() throws
    func update(_ session: Session, title: String?, tags: [String]?) throws
    func count() throws -> Int
    
    // Attachment operations
    func saveAttachment(_ attachment: SessionAttachment, to session: Session) throws
    func deleteAttachment(_ attachment: SessionAttachment, from session: Session) throws
    
    // Chat history operations
    func saveChatMessage(_ message: ChatMessage, to session: Session) throws
    func deleteChatHistory(from session: Session) throws
}

/// Repository for Session CRUD operations using SwiftData
@MainActor
final class SessionRepository: SessionRepositoryProtocol {
    
    // MARK: - Properties
    
    private let modelContext: ModelContext
    
    // MARK: - Initialization
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - CRUD Operations
    
    /// Fetches all sessions sorted by creation date (newest first)
    func fetchAll() throws -> [Session] {
        let descriptor = FetchDescriptor<Session>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }
    
    /// Fetches sessions with pagination support
    /// - Parameters:
    ///   - limit: Maximum number of sessions to fetch
    ///   - offset: Number of sessions to skip (for pagination)
    /// - Returns: Array of sessions sorted by creation date (newest first)
    func fetch(limit: Int, offset: Int = 0) throws -> [Session] {
        var descriptor = FetchDescriptor<Session>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        descriptor.fetchOffset = offset
        return try modelContext.fetch(descriptor)
    }
    
    /// Fetches a single session by ID
    func fetch(id: UUID) throws -> Session? {
        let predicate = #Predicate<Session> { session in
            session.id == id
        }
        var descriptor = FetchDescriptor<Session>(predicate: predicate)
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }
    
    /// Saves a new session
    func save(_ session: Session) throws {
        modelContext.insert(session)
        try modelContext.save()
        debugLog("Session saved: \(session.id)")
    }
    
    /// Deletes a session
    func delete(_ session: Session) throws {
        modelContext.delete(session)
        try modelContext.save()
        debugLog("Session deleted: \(session.id)")
    }
    
    /// Deletes all sessions
    func deleteAll() throws {
        let sessions = try fetchAll()
        for session in sessions {
            modelContext.delete(session)
        }
        try modelContext.save()
        debugLog("All sessions deleted")
    }
    
    /// Updates a session's title and/or tags
    func update(_ session: Session, title: String?, tags: [String]?) throws {
        if let title = title {
            session.title = title
        }
        if let tags = tags {
            session.tags = tags
        }
        session.version += 1
        try modelContext.save()
        debugLog("Session updated: \(session.id)")
    }
    
    /// Returns the total count of sessions
    func count() throws -> Int {
        let descriptor = FetchDescriptor<Session>()
        return try modelContext.fetchCount(descriptor)
    }
    
    // MARK: - Attachment Operations
    
    /// Saves an attachment and associates it with a session
    func saveAttachment(_ attachment: SessionAttachment, to session: Session) throws {
        session.attachments.append(attachment)
        modelContext.insert(attachment)
        try modelContext.save()
        debugLog("Attachment saved to session: \(session.id)")
    }
    
    /// Deletes an attachment from a session
    func deleteAttachment(_ attachment: SessionAttachment, from session: Session) throws {
        if let index = session.attachments.firstIndex(where: { $0.id == attachment.id }) {
            session.attachments.remove(at: index)
        }
        modelContext.delete(attachment)
        try modelContext.save()
        debugLog("Attachment deleted from session: \(session.id)")
    }
    
    // MARK: - Chat History Operations
    
    /// Saves a chat message to a session
    func saveChatMessage(_ message: ChatMessage, to session: Session) throws {
        session.chatHistory.append(message)
        modelContext.insert(message)
        try modelContext.save()
        debugLog("Chat message saved to session: \(session.id)")
    }
    
    /// Deletes all chat history from a session
    func deleteChatHistory(from session: Session) throws {
        for message in session.chatHistory {
            modelContext.delete(message)
        }
        session.chatHistory.removeAll()
        try modelContext.save()
        debugLog("Chat history deleted from session: \(session.id)")
    }
    
    // MARK: - Private Methods
    
    private func debugLog(_ message: String) {
        #if DEBUG
        print("[SessionRepository] \(message)")
        #endif
    }
}
