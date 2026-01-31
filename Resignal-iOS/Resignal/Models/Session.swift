//
//  Session.swift
//  Resignal
//
//  Core data model for interview analysis sessions.
//

import Foundation
import SwiftData

/// Available rubric types for interview analysis
enum Rubric: String, CaseIterable, Codable, Sendable {
    case softwareEngineering = "Software Engineering"
    case productManagement = "Product Management"
    case dataScience = "Data Science"
    case design = "Design"
    case behavioral = "Behavioral"
    case general = "General"

    nonisolated var description: String { rawValue }
}

/// Transcription mode for sessions
enum TranscriptionMode: String, Codable, Sendable {
    case manual
    case automatic
}

/// Represents a single interview analysis session
@Model
final class Session {
    
    // MARK: - Properties
    
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var title: String
    var role: String?
    var inputText: String
    var structuredFeedback: StructuredFeedback?
    var rubric: String
    var tags: [String]
    var version: Int
    
    // New properties for audio recording and attachments
    var audioFileURL: String?
    var transcriptionMode: String
    @Relationship(deleteRule: .cascade) var attachments: [SessionAttachment]
    @Relationship(deleteRule: .cascade) var chatHistory: [ChatMessage]
    
    // MARK: - Initialization
    
    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        title: String = "",
        role: String? = nil,
        inputText: String = "",
        structuredFeedback: StructuredFeedback? = nil,
        rubric: Rubric = .softwareEngineering,
        tags: [String] = [],
        version: Int = 2,
        audioFileURL: URL? = nil,
        transcriptionMode: TranscriptionMode = .manual,
        attachments: [SessionAttachment] = [],
        chatHistory: [ChatMessage] = []
    ) {
        self.id = id
        self.createdAt = createdAt
        self.title = title
        self.role = role
        self.inputText = inputText
        self.structuredFeedback = structuredFeedback
        self.rubric = rubric.rawValue
        self.tags = tags
        self.version = version
        self.audioFileURL = audioFileURL?.path
        self.transcriptionMode = transcriptionMode.rawValue
        self.attachments = attachments
        self.chatHistory = chatHistory
    }
    
    // MARK: - Computed Properties
    
    /// Returns the rubric as an enum type
    var rubricType: Rubric {
        get { Rubric(rawValue: rubric) ?? .general }
        set { rubric = newValue.rawValue }
    }
    
    /// Returns the transcription mode as an enum type
    var transcriptionModeType: TranscriptionMode {
        get { TranscriptionMode(rawValue: transcriptionMode) ?? .manual }
        set { transcriptionMode = newValue.rawValue }
    }
    
    /// Returns the audio file URL as a URL object if available
    var audioURL: URL? {
        guard let audioFileURL = audioFileURL else { return nil }
        return URL(fileURLWithPath: audioFileURL)
    }
    
    /// Returns true if the session has an audio recording
    var hasAudioRecording: Bool {
        audioFileURL != nil
    }
    
    /// Returns true if the session has attachments
    var hasAttachments: Bool {
        !attachments.isEmpty
    }
    
    /// Returns a preview of the input text (first 100 characters)
    var inputPreview: String {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count <= 100 {
            return trimmed
        }
        return String(trimmed.prefix(100)) + "..."
    }
    
    /// Auto-generates a title from the first question or uses a default
    var displayTitle: String {
        if !title.isEmpty {
            return title
        }
        
        // Try to extract first question
        let lines = inputText.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.contains("?") || trimmed.lowercased().starts(with: "q:") {
                let preview = String(trimmed.prefix(50))
                return preview.count < trimmed.count ? preview + "..." : preview
            }
        }
        
        // Fallback to date-based title
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return "Session - \(formatter.string(from: createdAt))"
    }
    
    /// Checks if the session has been analyzed
    var hasAnalysis: Bool {
        structuredFeedback != nil
    }
}

// MARK: - Sample Data

extension Session {
    static var sample: Session {
        Session(
            title: "iOS Engineer Interview",
            role: "Senior iOS Engineer",
            inputText: """
            Q: Tell me about a challenging iOS project you worked on.
            
            A: I led the development of a real-time collaboration feature for our document editing app. The challenge was synchronizing changes across multiple devices with minimal latency while handling offline scenarios gracefully.
            
            We implemented a CRDT-based approach using Operational Transformation. I designed the sync protocol and worked closely with our backend team to optimize WebSocket connections.
            
            The result was a 40% reduction in sync conflicts and 99.9% data consistency across devices.
            
            Q: How do you approach testing in iOS development?
            
            A: I follow a testing pyramid approach. Unit tests form the base, covering business logic and view models. I use XCTest for unit tests and combine it with dependency injection to make code testable.
            
            For integration tests, I focus on critical user flows. UI tests are used sparingly for smoke tests since they're slower.
            
            I also advocate for snapshot testing for UI components to catch visual regressions early.
            """,
            rubric: .softwareEngineering,
            tags: ["iOS", "Technical", "Senior"],
            version: 1
        )
    }
    
    static var sampleWithAnalysis: Session {
        let session = sample
        session.structuredFeedback = StructuredFeedback(
            summary: "The candidate demonstrated strong technical knowledge in iOS development, particularly in real-time synchronization and testing practices. Answers were well-structured with concrete examples.",
            strengths: [
                "Technical Depth: Showed deep understanding of CRDTs and Operational Transformation for real-time sync",
                "Quantifiable Results: Provided specific metrics (40% reduction, 99.9% consistency)",
                "Cross-functional Collaboration: Mentioned working with backend team",
                "Testing Philosophy: Clear understanding of testing pyramid and practical trade-offs"
            ],
            improvement: [
                "Limited Scope: Could have mentioned more about error handling and edge cases",
                "No Mention of User Experience: Didn't discuss how technical decisions impacted UX",
                "Offline Handling: Briefly mentioned but didn't elaborate on the strategy"
            ],
            hiringSignal: "Strong Hire - The candidate demonstrates excellent technical depth, clear communication, and practical experience with complex systems.",
            keyObservations: [
                "Strong understanding of distributed systems concepts (CRDTs, Operational Transformation)",
                "Practical approach to testing with clear trade-off awareness",
                "Good collaboration skills evidenced by cross-team work",
                "Could improve on discussing user experience implications of technical decisions"
            ]
        )
        return session
    }
}

