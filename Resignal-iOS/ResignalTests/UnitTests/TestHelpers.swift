//
//  TestHelpers.swift
//  ResignalTests
//
//  Created by Kai Chen on 12/31/25.
//

import Foundation
@testable import Resignal

// MARK: - Mock Session Repository

@MainActor
final class MockSessionRepository: SessionRepositoryProtocol {
    var savedSessions: [Session] = []
    var deletedSessions: [Session] = []
    var updatedSessions: [(session: Session, title: String?, tags: [String]?)] = []
    var shouldThrowError: Bool = false

    func fetchAll() throws -> [Session] {
        if shouldThrowError { throw TestError.mockError }
        return savedSessions
    }

    func fetch(id: UUID) throws -> Session? {
        if shouldThrowError { throw TestError.mockError }
        return savedSessions.first { $0.id == id }
    }

    func fetch(limit: Int, offset: Int) throws -> [Session] {
        if shouldThrowError { throw TestError.mockError }
        let sorted = savedSessions.sorted { $0.createdAt > $1.createdAt }
        let start = min(offset, sorted.count)
        let end = min(offset + limit, sorted.count)
        return Array(sorted[start..<end])
    }

    func count() throws -> Int {
        if shouldThrowError { throw TestError.mockError }
        return savedSessions.count
    }

    func save(_ session: Session) throws {
        if shouldThrowError { throw TestError.mockError }
        savedSessions.append(session)
    }

    func delete(_ session: Session) throws {
        if shouldThrowError { throw TestError.mockError }
        deletedSessions.append(session)
        savedSessions.removeAll { $0.id == session.id }
    }

    func deleteAll() throws {
        if shouldThrowError { throw TestError.mockError }
        deletedSessions.append(contentsOf: savedSessions)
        savedSessions.removeAll()
    }

    func update(_ session: Session, title: String?, tags: [String]?) throws {
        if shouldThrowError { throw TestError.mockError }
        updatedSessions.append((session, title, tags))
    }
}

// MARK: - Test Error

enum TestError: Error {
    case mockError
}

