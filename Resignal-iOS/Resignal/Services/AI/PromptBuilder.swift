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
    /// - Parameters:
    ///   - inputText: The interview Q&A or transcript
    ///   - role: Optional role being interviewed for
    ///   - rubric: The evaluation rubric to use
    /// - Returns: The formatted prompt string
    nonisolated static func buildPrompt(
        inputText: String,
        role: String?,
        rubric: Rubric
    ) -> String {
        var prompt = """
        Analyze the following interview transcript and provide structured feedback.
        
        """
        
        if let role = role, !role.isEmpty {
            prompt += "The candidate is interviewing for: \(role)\n"
        }
        
        prompt += "Evaluation rubric: \(rubric.description)\n\n"
        prompt += rubricGuidance(for: rubric)
        prompt += "\n\n---\n\n"
        prompt += "INTERVIEW TRANSCRIPT:\n\n"
        prompt += inputText
        prompt += "\n\n---\n\n"
        prompt += "Please provide your analysis following the required format."
        
        return prompt
    }
    
    /// Returns rubric-specific guidance to append to the prompt
    /// - Parameter rubric: The evaluation rubric
    /// - Returns: Additional guidance string
    nonisolated static func rubricGuidance(for rubric: Rubric) -> String {
        switch rubric {
        case .softwareEngineering:
            return """
            Focus on:
            - Technical accuracy and depth
            - Problem-solving approach
            - Code quality considerations
            - System design thinking
            - Communication of technical concepts
            """
        case .productManagement:
            return """
            Focus on:
            - Product sense and user empathy
            - Prioritization frameworks
            - Metrics and success criteria
            - Stakeholder management
            - Strategic thinking
            """
        case .dataScience:
            return """
            Focus on:
            - Statistical rigor
            - Model selection rationale
            - Data quality considerations
            - Business impact translation
            - Experimental design
            """
        case .design:
            return """
            Focus on:
            - User-centered thinking
            - Design process clarity
            - Visual and interaction decisions
            - Accessibility considerations
            - Iteration and feedback handling
            """
        case .behavioral:
            return """
            Focus on:
            - STAR method usage (Situation, Task, Action, Result)
            - Specific examples and outcomes
            - Self-awareness and growth mindset
            - Team collaboration
            - Leadership qualities
            """
        case .general:
            return """
            Focus on:
            - Clarity and structure of responses
            - Relevance to questions asked
            - Use of specific examples
            - Professional communication
            - Enthusiasm and engagement
            """
        }
    }
}
