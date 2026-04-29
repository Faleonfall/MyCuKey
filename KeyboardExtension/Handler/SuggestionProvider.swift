import Foundation

// MARK: - Suggestion Provider

protocol SuggestionProvider {
    func candidates(
        for prepared: PreparedCorrectionContext,
        engine: AutocorrectionEngine,
        boostedTerms: [SuggestionBoostTerm]
    ) -> [(result: AutocorrectionResult, strength: SuggestionStrength)]
}

// MARK: - Boost Terms

struct SuggestionBoostTerm: Hashable {
    let word: String
    let source: CorrectionSource
}

// MARK: - Future Hybrid Provider

struct HybridSuggestionProvider: SuggestionProvider {
    static let shared = HybridSuggestionProvider()

    let shortTokenProvider: ShortTokenSuggestionProvider
    let localProvider: LocalSuggestionProvider

    init(
        shortTokenProvider: ShortTokenSuggestionProvider = .shared,
        localProvider: LocalSuggestionProvider = .shared
    ) {
        self.shortTokenProvider = shortTokenProvider
        self.localProvider = localProvider
    }

    func candidates(
        for prepared: PreparedCorrectionContext,
        engine: AutocorrectionEngine,
        boostedTerms: [SuggestionBoostTerm]
    ) -> [(result: AutocorrectionResult, strength: SuggestionStrength)] {
        if prepared.token.correctionTargetLowercased.count <= 3 {
            return shortTokenProvider.candidates(
                for: prepared,
                engine: engine,
                boostedTerms: boostedTerms
            )
        }

        return localProvider.candidates(for: prepared, engine: engine, boostedTerms: boostedTerms)
    }
}
