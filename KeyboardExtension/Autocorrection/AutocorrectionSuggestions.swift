// MARK: - Suggestion Models

struct AutocorrectionSuggestion: Equatable {
    let text: String
    let source: CorrectionSource
    let confidence: Double
}

struct AutocorrectionSuggestionSet: Equatable {
    let token: CorrectionToken
    let suggestions: [AutocorrectionSuggestion]
}
