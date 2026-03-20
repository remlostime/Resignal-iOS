//
//  MockAppReviewService.swift
//  Resignal
//
//  Mock implementation of AppReviewServiceProtocol for previews and testing.
//

import Foundation
import Observation

@MainActor
@Observable
final class MockAppReviewService: AppReviewServiceProtocol {
    
    private(set) var lifetimeSessionCount: Int = 0
    private(set) var lifetimeAskMessageCount: Int = 0
    var hasPendingPrompt: Bool = false
    
    private var _shouldPrompt: Bool = false
    
    init(shouldPrompt: Bool = false) {
        self._shouldPrompt = shouldPrompt
    }
    
    func shouldPromptReview() -> Bool {
        _shouldPrompt
    }
    
    func recordSessionCompleted() {
        lifetimeSessionCount += 1
    }
    
    func recordAskMessageSent() {
        lifetimeAskMessageCount += 1
    }
    
    func recordPromptShown() {}
    func recordReviewSubmitted() {}
    func recordDismissed() {}
}
