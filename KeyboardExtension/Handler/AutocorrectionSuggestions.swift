enum AutocorrectionSuggestionKind: Equatable {
    case candidate
}

struct AutocorrectionSuggestion: Equatable {
    let text: String
    let source: CorrectionSource
    let confidence: Double
    let kind: AutocorrectionSuggestionKind
}

struct AutocorrectionSuggestionSet: Equatable {
    let token: CorrectionToken
    let suggestions: [AutocorrectionSuggestion]
}
