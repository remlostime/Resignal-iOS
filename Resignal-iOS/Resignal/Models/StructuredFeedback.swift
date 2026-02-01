//
//  StructuredFeedback.swift
//  Resignal
//
//  Structured feedback model for AI analysis results.
//

import Foundation

/// Structured feedback from AI analysis
/// Contains organized sections for interview evaluation
struct StructuredFeedback: Codable, Sendable, Equatable {
    
    // MARK: - Properties
    
    /// Server-generated title for the session
    let title: String
    
    /// Overall summary of the interview performance
    let summary: String
    
    /// List of identified strengths
    let strengths: [String]
    
    /// List of areas for improvement
    let improvement: [String]
    
    /// Overall hiring signal/recommendation
    let hiringSignal: String
    
    /// Key observations from the interview
    let keyObservations: [String]
    
    // MARK: - CodingKeys
    
    enum CodingKeys: String, CodingKey {
        case title
        case summary
        case strengths
        case improvement
        case hiringSignal = "hiring_signal"
        case keyObservations = "key_observations"
    }
    
    // MARK: - Initialization
    
    init(
        title: String,
        summary: String,
        strengths: [String],
        improvement: [String],
        hiringSignal: String,
        keyObservations: [String]
    ) {
        self.title = title
        self.summary = summary
        self.strengths = strengths
        self.improvement = improvement
        self.hiringSignal = hiringSignal
        self.keyObservations = keyObservations
    }
}

// MARK: - Sample Data

extension StructuredFeedback {
    static var sample: StructuredFeedback {
        StructuredFeedback(
            title: "iOS Development & Testing Practices",
            summary: "The candidate provided 2 response(s), demonstrating understanding of key concepts. The responses show a mix of strong knowledge and areas that could benefit from more specific examples.",
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
                "Candidate demonstrates good understanding of CRDT-based synchronization",
                "Testing philosophy aligns with industry best practices",
                "Shows experience with cross-functional collaboration",
                "Could improve on discussing edge cases and error handling"
            ]
        )
    }
}
