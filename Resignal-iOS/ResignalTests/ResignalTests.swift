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

@MainActor
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

@MainActor
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

// MARK: - Test Mocks

@MainActor
final class MockSessionRepository: SessionRepositoryProtocol {
    var savedSessions: [Session] = []
    var deletedSessions: [Session] = []
    var updatedSessions: [(session: Session, title: String?, tags: [String]?)] = []
    var shouldThrowError: Bool = false

    func fetchAll() throws -> [Session] {
        if shouldThrowError { throw TestError.mockError }
        return savedSessions
    }

    func fetch(id: UUID) throws -> Session? {
        if shouldThrowError { throw TestError.mockError }
        return savedSessions.first { $0.id == id }
    }

    func save(_ session: Session) throws {
        if shouldThrowError { throw TestError.mockError }
        savedSessions.append(session)
    }

    func delete(_ session: Session) throws {
        if shouldThrowError { throw TestError.mockError }
        deletedSessions.append(session)
        savedSessions.removeAll { $0.id == session.id }
    }

    func deleteAll() throws {
        if shouldThrowError { throw TestError.mockError }
        deletedSessions.append(contentsOf: savedSessions)
        savedSessions.removeAll()
    }

    func update(_ session: Session, title: String?, tags: [String]?) throws {
        if shouldThrowError { throw TestError.mockError }
        updatedSessions.append((session, title, tags))
    }
}

enum TestError: Error {
    case mockError
}

// MARK: - Date Extension Tests

import Foundation

struct DateExtensionTests {

    @Test("relativeFormatted returns non-empty string")
    func relativeFormattedNotEmpty() async throws {
        let date = Date()
        let formatted = date.relativeFormatted
        #expect(!formatted.isEmpty)
    }

    @Test("relativeFormatted for past date")
    func relativeFormattedPastDate() async throws {
        let pastDate = Date().addingTimeInterval(-86400) // 1 day ago
        let formatted = pastDate.relativeFormatted
        #expect(!formatted.isEmpty)
    }

    @Test("shortFormatted returns non-empty string")
    func shortFormattedNotEmpty() async throws {
        let date = Date()
        let formatted = date.shortFormatted
        #expect(!formatted.isEmpty)
    }

    @Test("shortFormatted contains date components")
    func shortFormattedContainsComponents() async throws {
        let date = Date()
        let formatted = date.shortFormatted
        // Short format should contain separators like / or - or :
        let hasDateSeparator = formatted.contains("/") || formatted.contains("-") || formatted.contains(".")
        let hasTimeSeparator = formatted.contains(":")
        #expect(hasDateSeparator || hasTimeSeparator)
    }

    @Test("mediumFormatted returns non-empty string")
    func mediumFormattedNotEmpty() async throws {
        let date = Date()
        let formatted = date.mediumFormatted
        #expect(!formatted.isEmpty)
    }

    @Test("mediumFormatted is longer than shortFormatted")
    func mediumFormattedLongerThanShort() async throws {
        let date = Date()
        let short = date.shortFormatted
        let medium = date.mediumFormatted
        #expect(medium.count >= short.count)
    }
}

// MARK: - Router Tests

@MainActor
struct RouterTests {

    @Test("Initial path is empty")
    func initialPathEmpty() async throws {
        let router = Router()
        #expect(router.path.isEmpty)
    }

    @Test("navigate appends route to path")
    func navigateAppendsRoute() async throws {
        let router = Router()
        router.navigate(to: .settings)
        #expect(router.path.count == 1)
        #expect(router.path.first == .settings)
    }

    @Test("navigate multiple routes builds path")
    func navigateMultipleRoutes() async throws {
        let router = Router()
        router.navigate(to: .settings)
        router.navigate(to: .editor(session: nil))
        #expect(router.path.count == 2)
        #expect(router.path[0] == .settings)
        #expect(router.path[1] == .editor(session: nil))
    }

    @Test("pop removes last route")
    func popRemovesLastRoute() async throws {
        let router = Router()
        router.navigate(to: .settings)
        router.navigate(to: .editor(session: nil))
        router.pop()
        #expect(router.path.count == 1)
        #expect(router.path.first == .settings)
    }

    @Test("pop on empty path does nothing")
    func popOnEmptyPathSafe() async throws {
        let router = Router()
        router.pop()
        #expect(router.path.isEmpty)
    }

    @Test("popToRoot clears all routes")
    func popToRootClearsPath() async throws {
        let router = Router()
        router.navigate(to: .settings)
        router.navigate(to: .editor(session: nil))
        router.navigate(to: .settings)
        router.popToRoot()
        #expect(router.path.isEmpty)
    }

    @Test("replace replaces last route")
    func replaceReplacesLastRoute() async throws {
        let router = Router()
        router.navigate(to: .settings)
        router.navigate(to: .editor(session: nil))
        router.replace(with: .settings)
        #expect(router.path.count == 2)
        #expect(router.path.last == .settings)
    }

    @Test("replace on empty path adds route")
    func replaceOnEmptyPathAddsRoute() async throws {
        let router = Router()
        router.replace(with: .settings)
        #expect(router.path.count == 1)
        #expect(router.path.first == .settings)
    }
}

// MARK: - Route Enum Tests

@MainActor
struct RouteTests {

    @Test("Route.home equals Route.home")
    func homeEqualsHome() async throws {
        #expect(Route.home == Route.home)
    }

    @Test("Route.settings equals Route.settings")
    func settingsEqualsSettings() async throws {
        #expect(Route.settings == Route.settings)
    }

    @Test("Route.editor with nil equals Route.editor with nil")
    func editorNilEqualsEditorNil() async throws {
        #expect(Route.editor(session: nil) == Route.editor(session: nil))
    }

    @Test("Route.editor with same session equals")
    func editorSameSessionEquals() async throws {
        let session = Session(inputText: "Test")
        #expect(Route.editor(session: session) == Route.editor(session: session))
    }

    @Test("Route.result with same session equals")
    func resultSameSessionEquals() async throws {
        let session = Session(inputText: "Test")
        #expect(Route.result(session: session) == Route.result(session: session))
    }

    @Test("Different routes are not equal")
    func differentRoutesNotEqual() async throws {
        #expect(Route.home != Route.settings)
        #expect(Route.editor(session: nil) != Route.settings)
    }

    @Test("Route.home is hashable")
    func homeIsHashable() async throws {
        var set: Set<Route> = []
        set.insert(.home)
        set.insert(.home)
        #expect(set.count == 1)
    }

    @Test("Route.settings is hashable")
    func settingsIsHashable() async throws {
        var set: Set<Route> = []
        set.insert(.settings)
        set.insert(.settings)
        #expect(set.count == 1)
    }

    @Test("Different routes hash differently")
    func differentRoutesHashDifferently() async throws {
        var set: Set<Route> = []
        set.insert(.home)
        set.insert(.settings)
        set.insert(.editor(session: nil))
        #expect(set.count == 3)
    }
}

// MARK: - Feedback Parsing Tests

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

// MARK: - EditorViewModel Tests

@MainActor
struct EditorViewModelTests {

    @Test("canAnalyze returns false for empty input")
    func canAnalyzeFalseForEmptyInput() async throws {
        let viewModel = EditorViewModel(
            aiClient: MockAIClient(),
            sessionRepository: MockSessionRepository()
        )
        viewModel.inputText = ""
        #expect(!viewModel.canAnalyze)
    }

    @Test("canAnalyze returns false for short input")
    func canAnalyzeFalseForShortInput() async throws {
        let viewModel = EditorViewModel(
            aiClient: MockAIClient(),
            sessionRepository: MockSessionRepository()
        )
        viewModel.inputText = "Short"
        #expect(!viewModel.canAnalyze)
    }

    @Test("canAnalyze returns true for valid input")
    func canAnalyzeTrueForValidInput() async throws {
        let viewModel = EditorViewModel(
            aiClient: MockAIClient(),
            sessionRepository: MockSessionRepository()
        )
        viewModel.inputText = "This is a valid input text that is long enough for analysis."
        #expect(viewModel.canAnalyze)
    }

    @Test("canAnalyze ignores whitespace-only input")
    func canAnalyzeIgnoresWhitespace() async throws {
        let viewModel = EditorViewModel(
            aiClient: MockAIClient(),
            sessionRepository: MockSessionRepository()
        )
        viewModel.inputText = "                                        "
        #expect(!viewModel.canAnalyze)
    }

    @Test("characterCountMessage shows remaining for short input")
    func characterCountMessageShowsRemaining() async throws {
        let viewModel = EditorViewModel(
            aiClient: MockAIClient(),
            sessionRepository: MockSessionRepository()
        )
        viewModel.inputText = "Short"
        #expect(viewModel.characterCountMessage.contains("more characters needed"))
    }

    @Test("characterCountMessage shows count for valid input")
    func characterCountMessageShowsCount() async throws {
        let viewModel = EditorViewModel(
            aiClient: MockAIClient(),
            sessionRepository: MockSessionRepository()
        )
        viewModel.inputText = "This is a valid input text that is long enough."
        #expect(viewModel.characterCountMessage.contains("characters"))
        #expect(!viewModel.characterCountMessage.contains("needed"))
    }

    @Test("isEditing is false for new session")
    func isEditingFalseForNewSession() async throws {
        let viewModel = EditorViewModel(
            aiClient: MockAIClient(),
            sessionRepository: MockSessionRepository()
        )
        #expect(!viewModel.isEditing)
    }

    @Test("isEditing is true for existing session")
    func isEditingTrueForExistingSession() async throws {
        let session = Session(inputText: "Existing session")
        let viewModel = EditorViewModel(
            aiClient: MockAIClient(),
            sessionRepository: MockSessionRepository(),
            session: session
        )
        #expect(viewModel.isEditing)
    }

    @Test("Pre-populates from existing session")
    func prePopulatesFromSession() async throws {
        let session = Session(
            title: "Test",
            role: "iOS Developer",
            inputText: "Test input",
            rubric: .softwareEngineering,
            tags: ["swift", "ios"]
        )
        let viewModel = EditorViewModel(
            aiClient: MockAIClient(),
            sessionRepository: MockSessionRepository(),
            session: session
        )

        #expect(viewModel.role == "iOS Developer")
        #expect(viewModel.rubric == .softwareEngineering)
        #expect(viewModel.inputText == "Test input")
        #expect(viewModel.tags == ["swift", "ios"])
    }

    @Test("Initial state is not analyzing")
    func initialStateNotAnalyzing() async throws {
        let viewModel = EditorViewModel(
            aiClient: MockAIClient(),
            sessionRepository: MockSessionRepository()
        )
        #expect(!viewModel.isAnalyzing)
        #expect(viewModel.errorMessage == nil)
    }
}
