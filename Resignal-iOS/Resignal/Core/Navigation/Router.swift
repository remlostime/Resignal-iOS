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
    case editor(initialTranscript: String? = nil, audioURL: URL? = nil, recordingId: UUID? = nil)
    case interviewDetail(interviewId: String)
    case recording
    case draft(recordingId: UUID)
    
    func hash(into hasher: inout Hasher) {
        switch self {
        case .home:
            hasher.combine("home")
        case .editor(let transcript, let audioURL, let recordingId):
            hasher.combine("editor")
            hasher.combine(transcript)
            hasher.combine(audioURL)
            hasher.combine(recordingId)
        case .interviewDetail(let interviewId):
            hasher.combine("interviewDetail")
            hasher.combine(interviewId)
        case .recording:
            hasher.combine("recording")
        case .draft(let recordingId):
            hasher.combine("draft")
            hasher.combine(recordingId)
        }
    }
    
    static func == (lhs: Route, rhs: Route) -> Bool {
        switch (lhs, rhs) {
        case (.home, .home):
            return true
        case (.editor(let lhsTranscript, let lhsURL, let lhsId), .editor(let rhsTranscript, let rhsURL, let rhsId)):
            return lhsTranscript == rhsTranscript && lhsURL == rhsURL && lhsId == rhsId
        case (.interviewDetail(let lhsId), .interviewDetail(let rhsId)):
            return lhsId == rhsId
        case (.recording, .recording):
            return true
        case (.draft(let lhsId), .draft(let rhsId)):
            return lhsId == rhsId
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
