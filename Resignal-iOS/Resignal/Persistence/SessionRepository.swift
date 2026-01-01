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
    func fetch(id: UUID) throws -> Session?
    func save(_ session: Session) throws
    func delete(_ session: Session) throws
    func deleteAll() throws
    func update(_ session: Session, title: String?, tags: [String]?) throws
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
    
    // MARK: - Private Methods
    
    private func debugLog(_ message: String) {
        #if DEBUG
        print("[SessionRepository] \(message)")
        #endif
    }
}

