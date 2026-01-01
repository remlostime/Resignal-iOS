//
//  EditorViewModelTests.swift
//  ResignalTests
//
//  Created by Kai Chen on 12/31/25.
//

import Testing
@testable import Resignal

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

