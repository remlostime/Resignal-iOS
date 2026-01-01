//
//  Router.swift
//  Resignal
//
//  Navigation router using NavigationStack with type-safe routes.
//

import SwiftUI

/// Defines all possible navigation destinations in the app
enum Route: Hashable {
    case home
    case editor(session: Session?)
    case result(session: Session)
    case settings
    
    func hash(into hasher: inout Hasher) {
        switch self {
        case .home:
            hasher.combine("home")
        case .editor(let session):
            hasher.combine("editor")
            hasher.combine(session?.id)
        case .result(let session):
            hasher.combine("result")
            hasher.combine(session.id)
        case .settings:
            hasher.combine("settings")
        }
    }
    
    static func == (lhs: Route, rhs: Route) -> Bool {
        switch (lhs, rhs) {
        case (.home, .home):
            return true
        case (.editor(let lhsSession), .editor(let rhsSession)):
            return lhsSession?.id == rhsSession?.id
        case (.result(let lhsSession), .result(let rhsSession)):
            return lhsSession.id == rhsSession.id
        case (.settings, .settings):
            return true
        default:
            return false
        }
    }
}

/// Observable router that manages navigation state
@MainActor
@Observable
final class Router {
    var path: [Route] = []
    
    func navigate(to route: Route) {
        path.append(route)
    }
    
    func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }
    
    func popToRoot() {
        path.removeAll()
    }
    
    func replace(with route: Route) {
        if !path.isEmpty {
            path.removeLast()
        }
        path.append(route)
    }
}

