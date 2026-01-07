//
//  RouteTests.swift
//  ResignalTests
//
//  Created by Kai Chen on 12/31/25.
//

import Testing
@testable import Resignal

@MainActor
struct RouteTests {

    @Test("Route.home equals Route.home")
    func homeEqualsHome() async throws {
        #expect(Route.home == Route.home)
    }

    @Test("Route.editor with nil equals Route.editor with nil")
    func editorNilEqualsEditorNil() async throws {
        #expect(Route.editor(session: nil) == Route.editor(session: nil))
    }

    @Test("Route.editor with same session equals")
    func editorSameSessionEquals() async throws {
        let session = Session(inputText: "Test")
        #expect(Route.editor(session: session) == Route.editor(session: session))
    }

    @Test("Route.result with same session equals")
    func resultSameSessionEquals() async throws {
        let session = Session(inputText: "Test")
        #expect(Route.result(session: session) == Route.result(session: session))
    }

    @Test("Route.home is hashable")
    func homeIsHashable() async throws {
        var set: Set<Route> = []
        set.insert(.home)
        set.insert(.home)
        #expect(set.count == 1)
    }

    @Test("Different routes hash differently")
    func differentRoutesHashDifferently() async throws {
        var set: Set<Route> = []
        set.insert(.home)
        set.insert(.editor(session: nil))
        #expect(set.count == 2)
    }
}

