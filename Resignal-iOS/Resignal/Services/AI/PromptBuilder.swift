//
//  PromptBuilder.swift
//  Resignal
//
//  Builds AI prompts for interview analysis with consistent formatting.
//

import Foundation

/// Builds prompts for AI analysis of interview responses
/// All members are nonisolated to allow use from any actor context
struct PromptBuilder: Sendable {

    // MARK: - System Prompt

    nonisolated static let systemPrompt = """
    You are an expert interview coach with deep experience in technical and behavioral interviews. \
    Your role is to analyze interview Q&A transcripts and provide actionable, specific feedback.
    
    Always structure your response using the following markdown format:
    
    ## Summary
    [2-3 sentence overview of the candidate's performance]
    
    ## Strengths
    [Bullet points highlighting what the candidate did well, with specific examples from their answers]
    
    ## Weaknesses
    [Bullet points identifying areas for improvement, with specific examples]
    
    ## Suggested Improved Answers
    [For each question where improvement is needed, provide a concrete example of a better answer]
    
    ## Follow-up Questions
    [4-5 questions an interviewer might ask based on the candidate's responses]
    
    Be specific, constructive, and focus on actionable improvements. Reference specific parts of the \
    candidate's answers when providing feedback.
    """
    
    // MARK: - Public Methods

    /// Builds the complete prompt for analysis
    /// - Parameter inputText: The interview Q&A or transcript
    /// - Returns: The formatted prompt string
    nonisolated static func buildPrompt(inputText: String) -> String {
        let prompt = """
        Analyze the following interview transcript and provide structured feedback.
        
        ---
        
        INTERVIEW TRANSCRIPT:
        
        \(inputText)
        
        ---
        
        Please provide your analysis following the required format.
        """
        
        return prompt
    }
}
