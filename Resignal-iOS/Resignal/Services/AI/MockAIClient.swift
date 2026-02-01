//
//  MockAIClient.swift
//  Resignal
//
//  Mock AI client that returns deterministic sample feedback for development and testing.
//

import Foundation

/// Mock AI client for development and testing
/// Returns deterministic responses without requiring network access
actor MockAIClient: AIClient {

    // MARK: - Properties

    private var _isAnalyzing: Bool = false

    nonisolated var isAnalyzing: Bool {
        get async {
            await getIsAnalyzing()
        }
    }

    private func getIsAnalyzing() -> Bool {
        _isAnalyzing
    }

    private func setIsAnalyzing(_ value: Bool) {
        _isAnalyzing = value
    }

    // MARK: - AIClient Implementation

    nonisolated func analyze(_ request: AnalysisRequest) async throws -> AnalysisResponse {
        // Validate input
        let trimmedInput = request.inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedInput.count >= 20 else {
            throw AIClientError.invalidInput("Input text must be at least 20 characters")
        }

        // Generate deterministic feedback based on input
        let feedback = Self.generateFeedback(for: request)

        // Simulate network delay (1-2 seconds)
        try await Task.sleep(for: .milliseconds(Int.random(in: 1000...2000)))

        // Check for cancellation
        try Task.checkCancellation()

        return AnalysisResponse(feedback: feedback)
    }

    nonisolated func cancel() {
        // Mock client doesn't track cancellable tasks
    }
    
    // MARK: - Private Methods

    private nonisolated static func generateFeedback(for request: AnalysisRequest) -> StructuredFeedback {
        let questionCount = countQuestions(in: request.inputText)
        
        return StructuredFeedback(
            title: "Interview Analysis - \(questionCount) Q&A",
            summary: "The candidate provided \(questionCount) response(s), demonstrating understanding of key concepts. The responses show a mix of strong knowledge and areas that could benefit from more specific examples.",
            strengths: [
                "Clear Communication: Responses are well-structured and easy to follow",
                "Technical Foundation: Shows solid understanding of core concepts",
                "Concrete Examples: Provided specific instances from past experience",
                "Problem-Solving Mindset: Demonstrated analytical thinking approach",
                "Self-Awareness: Acknowledged challenges and learning opportunities"
            ],
            improvement: [
                "Depth of Detail: Some responses could benefit from more technical specifics",
                "Metrics and Outcomes: Could include more quantifiable results and impact",
                "Edge Cases: Limited discussion of error handling and edge scenarios",
                "Trade-offs: Could better articulate decision-making trade-offs"
            ],
            hiringSignal: "Lean Hire - The candidate shows strong potential with solid technical foundation and communication skills. With some refinement in providing more detailed examples and metrics, they would be a strong addition to the team.",
            keyObservations: [
                "Candidate demonstrates good understanding of core technical concepts",
                "Communication style is clear and well-organized",
                "Shows practical experience with real-world implementations",
                "Could improve on providing more quantifiable results and discussing edge cases"
            ]
        )
    }
    
    private nonisolated static func countQuestions(in text: String) -> Int {
        let patterns = ["Q:", "Question:", "?"]
        var count = 0

        for pattern in patterns {
            count += text.components(separatedBy: pattern).count - 1
        }

        return max(1, min(count, 10)) // Return between 1 and 10
    }
}

