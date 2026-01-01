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

    @Test("navigate appends route to path")
    func navigateAppendsRoute() async throws {
        let router = Router()
        router.navigate(to: .settings)
        #expect(router.path.count == 1)
        #expect(router.path.first == .settings)
    }

    @Test("navigate multiple routes builds path")
    func navigateMultipleRoutes() async throws {
        let router = Router()
        router.navigate(to: .settings)
        router.navigate(to: .editor(session: nil))
        #expect(router.path.count == 2)
        #expect(router.path[0] == .settings)
        #expect(router.path[1] == .editor(session: nil))
    }

    @Test("pop removes last route")
    func popRemovesLastRoute() async throws {
        let router = Router()
        router.navigate(to: .settings)
        router.navigate(to: .editor(session: nil))
        router.pop()
        #expect(router.path.count == 1)
        #expect(router.path.first == .settings)
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
        router.navigate(to: .settings)
        router.navigate(to: .editor(session: nil))
        router.navigate(to: .settings)
        router.popToRoot()
        #expect(router.path.isEmpty)
    }

    @Test("replace replaces last route")
    func replaceReplacesLastRoute() async throws {
        let router = Router()
        router.navigate(to: .settings)
        router.navigate(to: .editor(session: nil))
        router.replace(with: .settings)
        #expect(router.path.count == 2)
        #expect(router.path.last == .settings)
    }

    @Test("replace on empty path adds route")
    func replaceOnEmptyPathAddsRoute() async throws {
        let router = Router()
        router.replace(with: .settings)
        #expect(router.path.count == 1)
        #expect(router.path.first == .settings)
    }
}

