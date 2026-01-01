//
//  FeedbackParser.swift
//  Resignal
//
//  Utility for parsing AI feedback markdown into structured sections.
//

import Foundation

/// Parsed sections from the AI feedback
struct FeedbackSections: Sendable {
    var summary: String
    var strengths: String
    var weaknesses: String
    var suggestedAnswers: String
    var followUpQuestions: String
    var raw: String

    nonisolated init(
        summary: String = "",
        strengths: String = "",
        weaknesses: String = "",
        suggestedAnswers: String = "",
        followUpQuestions: String = "",
        raw: String = ""
    ) {
        self.summary = summary
        self.strengths = strengths
        self.weaknesses = weaknesses
        self.suggestedAnswers = suggestedAnswers
        self.followUpQuestions = followUpQuestions
        self.raw = raw
    }
}

/// Utility for parsing markdown feedback into structured sections
enum FeedbackParser {

    /// Parses markdown feedback into FeedbackSections
    nonisolated static func parse(_ feedback: String) -> FeedbackSections {
        var sections = FeedbackSections()
        sections.raw = feedback

        let patterns: [(String, WritableKeyPath<FeedbackSections, String>)] = [
            ("## Summary", \.summary),
            ("## Strengths", \.strengths),
            ("## Weaknesses", \.weaknesses),
            ("## Suggested Improved Answers", \.suggestedAnswers),
            ("## Follow-up Questions", \.followUpQuestions)
        ]

        for (index, (header, keyPath)) in patterns.enumerated() {
            if let startRange = feedback.range(of: header) {
                let startIndex = startRange.upperBound

                // Find the end (next header or end of string)
                var endIndex = feedback.endIndex
                for nextIndex in (index + 1)..<patterns.count {
                    if let nextRange = feedback.range(of: patterns[nextIndex].0) {
                        endIndex = nextRange.lowerBound
                        break
                    }
                }

                let content = String(feedback[startIndex..<endIndex])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                sections[keyPath: keyPath] = content
            }
        }

        return sections
    }
}

