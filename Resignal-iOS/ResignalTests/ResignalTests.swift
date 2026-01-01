//
//  ResignalTests.swift
//  ResignalTests
//
//  Created by Kai Chen on 12/31/25.
//

import Testing
@testable import Resignal

// MARK: - PromptBuilder Tests

struct PromptBuilderTests {
    
    @Test("Builds basic prompt with input text")
    func basicPrompt() async throws {
        let inputText = "Q: What is your experience?\nA: I have 5 years of iOS experience."
        let prompt = PromptBuilder.buildPrompt(
            inputText: inputText,
            role: nil,
            rubric: .softwareEngineering
        )
        
        #expect(prompt.contains("INTERVIEW TRANSCRIPT:"))
        #expect(prompt.contains(inputText))
        #expect(prompt.contains("Software Engineering"))
    }
    
    @Test("Includes role when provided")
    func promptWithRole() async throws {
        let role = "Senior iOS Engineer"
        let prompt = PromptBuilder.buildPrompt(
            inputText: "Sample text",
            role: role,
            rubric: .softwareEngineering
        )
        
        #expect(prompt.contains("interviewing for: \(role)"))
    }
    
    @Test("Does not include role line when nil")
    func promptWithoutRole() async throws {
        let prompt = PromptBuilder.buildPrompt(
            inputText: "Sample text",
            role: nil,
            rubric: .softwareEngineering
        )
        
        #expect(!prompt.contains("interviewing for:"))
    }
    
    @Test("Includes correct rubric for each type")
    func rubricTypes() async throws {
        for rubric in Rubric.allCases {
            let prompt = PromptBuilder.buildPrompt(
                inputText: "Sample text",
                role: nil,
                rubric: rubric
            )
            
            #expect(prompt.contains(rubric.description))
        }
    }
    
    @Test("System prompt contains required sections")
    func systemPromptStructure() async throws {
        let systemPrompt = PromptBuilder.systemPrompt
        
        #expect(systemPrompt.contains("## Summary"))
        #expect(systemPrompt.contains("## Strengths"))
        #expect(systemPrompt.contains("## Weaknesses"))
        #expect(systemPrompt.contains("## Suggested Improved Answers"))
        #expect(systemPrompt.contains("## Follow-up Questions"))
    }
    
    @Test("Rubric guidance returns non-empty string for all rubrics")
    func rubricGuidance() async throws {
        for rubric in Rubric.allCases {
            let guidance = PromptBuilder.rubricGuidance(for: rubric)
            #expect(!guidance.isEmpty)
            #expect(guidance.contains("Focus on:"))
        }
    }
}

// MARK: - MockAIClient Tests

struct MockAIClientTests {
    
    @Test("Returns deterministic response for valid input")
    func deterministicResponse() async throws {
        let client = MockAIClient()
        let request = AnalysisRequest(
            inputText: "Q: Tell me about yourself.\nA: I am a software engineer with 5 years of experience.",
            role: "iOS Engineer",
            rubric: .softwareEngineering
        )
        
        let response1 = try await client.analyze(request)
        let response2 = try await client.analyze(request)
        
        // Both responses should have the same structure
        #expect(response1.feedback.contains("## Summary"))
        #expect(response2.feedback.contains("## Summary"))
        #expect(response1.feedback.contains("## Strengths"))
        #expect(response1.feedback.contains("## Weaknesses"))
    }
    
    @Test("Throws error for input that is too short")
    func shortInputError() async throws {
        let client = MockAIClient()
        let request = AnalysisRequest(
            inputText: "Short",
            role: nil,
            rubric: .general
        )
        
        do {
            _ = try await client.analyze(request)
            Issue.record("Expected error for short input")
        } catch let error as AIClientError {
            if case .invalidInput = error {
                // Expected
            } else {
                Issue.record("Unexpected error type: \(error)")
            }
        }
    }
    
    @Test("Response contains expected markdown sections")
    func responseContainsSections() async throws {
        let client = MockAIClient()
        let request = AnalysisRequest(
            inputText: "Q: What is your greatest strength?\nA: Problem solving and attention to detail.",
            role: "Developer",
            rubric: .behavioral
        )
        
        let response = try await client.analyze(request)
        
        #expect(response.feedback.contains("## Summary"))
        #expect(response.feedback.contains("## Strengths"))
        #expect(response.feedback.contains("## Weaknesses"))
        #expect(response.feedback.contains("## Suggested Improved Answers"))
        #expect(response.feedback.contains("## Follow-up Questions"))
    }
    
    @Test("Response includes role when provided")
    func responseIncludesRole() async throws {
        let client = MockAIClient()
        let role = "Product Manager"
        let request = AnalysisRequest(
            inputText: "Q: Describe a product you launched.\nA: I led the launch of a mobile app that reached 1M users.",
            role: role,
            rubric: .productManagement
        )
        
        let response = try await client.analyze(request)
        
        #expect(response.feedback.contains(role))
    }
    
    @Test("Response includes rubric")
    func responseIncludesRubric() async throws {
        let client = MockAIClient()
        let rubric = Rubric.dataScience
        let request = AnalysisRequest(
            inputText: "Q: Explain your ML pipeline.\nA: We use a standard ETL process with feature engineering.",
            role: nil,
            rubric: rubric
        )
        
        let response = try await client.analyze(request)
        
        #expect(response.feedback.contains(rubric.description))
    }
    
    @Test("isAnalyzing returns correct state")
    func analyzingState() async throws {
        let client = MockAIClient()
        
        // Initially not analyzing
        let initialState = await client.isAnalyzing
        #expect(!initialState)
    }
}

// MARK: - Session Model Tests

struct SessionModelTests {
    
    @Test("Session auto-generates title from first question")
    func autoGeneratedTitle() async throws {
        let session = Session(
            title: "",
            inputText: "Q: What is your experience?\nA: I have many years of experience."
        )
        
        #expect(session.displayTitle.contains("What is your experience"))
    }
    
    @Test("Session uses custom title when set")
    func customTitle() async throws {
        let customTitle = "My Interview Session"
        let session = Session(
            title: customTitle,
            inputText: "Q: Tell me about yourself."
        )
        
        #expect(session.displayTitle == customTitle)
    }
    
    @Test("Input preview truncates long text")
    func inputPreviewTruncation() async throws {
        let longText = String(repeating: "A", count: 200)
        let session = Session(inputText: longText)
        
        #expect(session.inputPreview.count <= 103) // 100 chars + "..."
        #expect(session.inputPreview.hasSuffix("..."))
    }
    
    @Test("hasAnalysis returns correct state")
    func hasAnalysisState() async throws {
        let sessionWithoutAnalysis = Session(outputFeedback: "")
        let sessionWithAnalysis = Session(outputFeedback: "Some feedback")
        
        #expect(!sessionWithoutAnalysis.hasAnalysis)
        #expect(sessionWithAnalysis.hasAnalysis)
    }
    
    @Test("Rubric type conversion works correctly")
    func rubricTypeConversion() async throws {
        let session = Session(rubric: .softwareEngineering)
        
        #expect(session.rubricType == .softwareEngineering)
        
        session.rubricType = .productManagement
        #expect(session.rubric == Rubric.productManagement.rawValue)
    }
}

// MARK: - Rubric Tests

struct RubricTests {
    
    @Test("All rubrics have descriptions")
    func rubricDescriptions() async throws {
        for rubric in Rubric.allCases {
            #expect(!rubric.description.isEmpty)
            #expect(rubric.description == rubric.rawValue)
        }
    }
    
    @Test("Rubric count matches expected")
    func rubricCount() async throws {
        #expect(Rubric.allCases.count == 6)
    }
}
