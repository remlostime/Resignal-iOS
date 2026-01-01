//
//  FeedbackParser.swift
//  Resignal
//
//  Utility for parsing AI feedback markdown into structured sections.
//

import Foundation

/// Parsed sections from the AI feedback
struct FeedbackSections: Sendable, Equatable {
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
    
    /// Section header patterns with their variations
    private static let sectionPatterns: [(headers: [String], keyPath: WritableKeyPath<FeedbackSections, String>)] = [
        (["## Summary", "## summary", "**Summary**", "Summary:"], \.summary),
        (["## Strengths", "## strengths", "**Strengths**", "Strengths:"], \.strengths),
        (["## Weaknesses", "## weaknesses", "## Areas for Improvement", "**Weaknesses**", "Weaknesses:"], \.weaknesses),
        (["## Suggested Improved Answers", "## Suggested Answers", "## Improvements", "**Suggested Improved Answers**"], \.suggestedAnswers),
        (["## Follow-up Questions", "## Follow Up Questions", "## Followup Questions", "**Follow-up Questions**"], \.followUpQuestions)
    ]

    /// Parses markdown feedback into FeedbackSections
    nonisolated static func parse(_ feedback: String) -> FeedbackSections {
        var sections = FeedbackSections()
        sections.raw = feedback

        for (index, (headers, keyPath)) in sectionPatterns.enumerated() {
            if let (startRange, _) = findSection(in: feedback, headers: headers) {
                let startIndex = startRange.upperBound
                
                // Find the end (next section header or end of string)
                var endIndex = feedback.endIndex
                for nextIndex in (index + 1)..<sectionPatterns.count {
                    if let (nextRange, _) = findSection(in: feedback, headers: sectionPatterns[nextIndex].headers) {
                        // Only use this as end if it comes after our start
                        if nextRange.lowerBound > startRange.upperBound {
                            endIndex = nextRange.lowerBound
                            break
                        }
                    }
                }
                
                // Also check for any markdown header that might indicate a new section
                let searchRange = startIndex..<endIndex
                if let genericHeaderRange = feedback.range(of: "\n## ", range: searchRange) {
                    endIndex = genericHeaderRange.lowerBound
                }

                let content = String(feedback[startIndex..<endIndex])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                sections[keyPath: keyPath] = content
            }
        }

        return sections
    }
    
    /// Finds a section header in the feedback using multiple possible header formats
    /// Returns the range of the matched header and the matched header string
    private static func findSection(in feedback: String, headers: [String]) -> (Range<String.Index>, String)? {
        for header in headers {
            // Try exact match first
            if let range = feedback.range(of: header) {
                return (range, header)
            }
            
            // Try case-insensitive match
            if let range = feedback.range(of: header, options: .caseInsensitive) {
                return (range, header)
            }
        }
        
        // Try to find just the section name (without formatting)
        for header in headers {
            // Extract the core text (remove ## and **)
            let coreText = header
                .replacingOccurrences(of: "## ", with: "")
                .replacingOccurrences(of: "**", with: "")
                .replacingOccurrences(of: ":", with: "")
                .trimmingCharacters(in: .whitespaces)
            
            // Look for the core text at the start of a line
            let pattern = "(?m)^\\s*(?:#{1,3}\\s*)?(?:\\*{1,2})?\\s*\(NSRegularExpression.escapedPattern(for: coreText))"
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: feedback, range: NSRange(feedback.startIndex..., in: feedback)),
               let range = Range(match.range, in: feedback) {
                return (range, coreText)
            }
        }
        
        return nil
    }
}
