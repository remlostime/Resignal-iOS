//
//  FeedbackParsingTests.swift
//  ResignalTests
//
//  Created by Kai Chen on 12/31/25.
//

import Testing
@testable import Resignal

struct FeedbackParsingTests {

    @Test("Parses valid markdown with all sections")
    func parsesAllSections() async throws {
        let markdown = """
        ## Summary
        This is a summary.

        ## Strengths
        - Strong point 1
        - Strong point 2

        ## Weaknesses
        - Weak point 1

        ## Suggested Improved Answers
        Better answer here.

        ## Follow-up Questions
        1. Question one?
        2. Question two?
        """

        let sections = FeedbackParser.parse(markdown)

        #expect(sections.summary.contains("This is a summary"))
        #expect(sections.strengths.contains("Strong point 1"))
        #expect(sections.weaknesses.contains("Weak point 1"))
        #expect(sections.suggestedAnswers.contains("Better answer"))
        #expect(sections.followUpQuestions.contains("Question one"))
    }

    @Test("Parses partial markdown with missing sections")
    func parsesPartialMarkdown() async throws {
        let markdown = """
        ## Summary
        Only summary here.

        ## Strengths
        Some strengths.
        """

        let sections = FeedbackParser.parse(markdown)

        #expect(sections.summary.contains("Only summary"))
        #expect(sections.strengths.contains("Some strengths"))
        #expect(sections.weaknesses.isEmpty)
        #expect(sections.suggestedAnswers.isEmpty)
        #expect(sections.followUpQuestions.isEmpty)
    }

    @Test("Parses empty string returns empty sections")
    func parsesEmptyString() async throws {
        let sections = FeedbackParser.parse("")

        #expect(sections.summary.isEmpty)
        #expect(sections.strengths.isEmpty)
        #expect(sections.weaknesses.isEmpty)
        #expect(sections.suggestedAnswers.isEmpty)
        #expect(sections.followUpQuestions.isEmpty)
    }

    @Test("Raw feedback is preserved")
    func rawFeedbackPreserved() async throws {
        let markdown = "## Summary\nTest content"
        let sections = FeedbackParser.parse(markdown)

        #expect(sections.raw == markdown)
    }
}

