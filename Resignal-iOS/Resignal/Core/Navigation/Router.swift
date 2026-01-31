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
    case editor(session: Session?, initialTranscript: String? = nil, audioURL: URL? = nil)
    case result(session: Session)
    case recording(session: Session?)
    
    func hash(into hasher: inout Hasher) {
        switch self {
        case .home:
            hasher.combine("home")
        case .editor(let session, let transcript, let audioURL):
            hasher.combine("editor")
            hasher.combine(session?.id)
            hasher.combine(transcript)
            hasher.combine(audioURL)
        case .result(let session):
            hasher.combine("result")
            hasher.combine(session.id)
        case .recording(let session):
            hasher.combine("recording")
            hasher.combine(session?.id)
        }
    }
    
    static func == (lhs: Route, rhs: Route) -> Bool {
        switch (lhs, rhs) {
        case (.home, .home):
            return true
        case (.editor(let lhsSession, let lhsTranscript, let lhsURL), .editor(let rhsSession, let rhsTranscript, let rhsURL)):
            return lhsSession?.id == rhsSession?.id && lhsTranscript == rhsTranscript && lhsURL == rhsURL
        case (.result(let lhsSession), .result(let rhsSession)):
            return lhsSession.id == rhsSession.id
        case (.recording(let lhsSession), .recording(let rhsSession)):
            return lhsSession?.id == rhsSession?.id
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

