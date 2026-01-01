//
//  PromptBuilderTests.swift
//  ResignalTests
//
//  Created by Kai Chen on 12/31/25.
//

import Testing
@testable import Resignal

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

