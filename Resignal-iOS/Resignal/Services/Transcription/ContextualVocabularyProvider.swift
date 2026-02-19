//
//  ContextualVocabularyProvider.swift
//  Resignal
//
//  Provides domain-specific vocabulary terms for speech recognition contextual biasing.
//

import Foundation

/// Provides contextual vocabulary terms to improve speech recognition accuracy
protocol ContextualVocabularyProvider: Sendable {
    /// Returns all vocabulary terms across all domains (deduplicated)
    func allTerms() -> [String]
    /// Returns vocabulary terms for a specific interview rubric
    func terms(for rubric: Rubric) -> [String]
}

/// Loads vocabulary from JSON files bundled in the app's ContextualVocabulary resource folder
final class ContextualVocabularyProviderImpl: ContextualVocabularyProvider {

    private let termsByFile: [String: [String]]

    private static let allFileNames = [
        "common",
        "mobile-engineering",
        "backend-engineering",
        "frontend-engineering",
        "product-management",
        "design",
        "data-science",
        "behavioral"
    ]

    init(bundle: Bundle = .main) {
        var loaded: [String: [String]] = [:]
        for name in Self.allFileNames {
            let url = bundle.url(
                forResource: name, withExtension: "json", subdirectory: "ContextualVocabulary"
            )
            guard let url else {
                // Fall back: try without subdirectory (flat bundle)
                if let flatURL = bundle.url(forResource: name, withExtension: "json") {
                    loaded[name] = Self.loadTerms(from: flatURL)
                } else {
                    print("⚠️ ContextualVocabulary: \(name).json not found in bundle")
                }
                continue
            }
            loaded[name] = Self.loadTerms(from: url)
        }
        self.termsByFile = loaded
    }

    func allTerms() -> [String] {
        let combined = termsByFile.values.flatMap { $0 }
        return Array(Set(combined))
    }

    func terms(for rubric: Rubric) -> [String] {
        let files = fileNames(for: rubric)
        let combined = files.flatMap { termsByFile[$0] ?? [] }
        return Array(Set(combined))
    }

    // MARK: - Private

    private func fileNames(for rubric: Rubric) -> [String] {
        switch rubric {
        case .softwareEngineering:
            return ["common", "mobile-engineering", "backend-engineering", "frontend-engineering"]
        case .productManagement:
            return ["common", "product-management"]
        case .design:
            return ["common", "design"]
        case .dataScience:
            return ["common", "data-science"]
        case .behavioral:
            return ["common", "behavioral"]
        case .general:
            return ["common"]
        }
    }

    private static func loadTerms(from url: URL) -> [String] {
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([String].self, from: data)
        } catch {
            print("⚠️ ContextualVocabulary: Failed to load \(url.lastPathComponent): \(error)")
            return []
        }
    }
}
