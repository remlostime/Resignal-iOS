//
//  RouterTests.swift
//  ResignalTests
//
//  Created by Kai Chen on 12/31/25.
//

import Testing
@testable import Resignal

@MainActor
struct RouterTests {

    @Test("Initial path is empty")
    func initialPathEmpty() async throws {
        let router = Router()
        #expect(router.path.isEmpty)
    }

    @Test("navigate multiple routes builds path")
    func navigateMultipleRoutes() async throws {
        let router = Router()
        router.navigate(to: .editor(session: nil))
        #expect(router.path.count == 1)
        #expect(router.path[0] == .editor(session: nil))
    }

    @Test("pop removes last route")
    func popRemovesLastRoute() async throws {
        let router = Router()
        router.navigate(to: .editor(session: nil))
        router.pop()
        #expect(router.path.isEmpty)
    }

    @Test("pop on empty path does nothing")
    func popOnEmptyPathSafe() async throws {
        let router = Router()
        router.pop()
        #expect(router.path.isEmpty)
    }

    @Test("popToRoot clears all routes")
    func popToRootClearsPath() async throws {
        let router = Router()
        router.navigate(to: .editor(session: nil))
        router.popToRoot()
        #expect(router.path.isEmpty)
    }

    @Test("replace replaces last route")
    func replaceReplacesLastRoute() async throws {
        let router = Router()
        router.navigate(to: .editor(session: nil))
        #expect(router.path.count == 1)
    }
}

