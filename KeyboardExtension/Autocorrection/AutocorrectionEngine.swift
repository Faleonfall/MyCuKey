import UIKit

// MARK: - Core Types

enum CorrectionSource: Equatable {
    case userInput
    case contraction
    case deterministicRule
    case localLexicon
    case nextWordLexicon
    case personalDictionary
    case shortTokenLexicon
    case supplementaryLexicon
    case textChecker
}

struct AutocorrectionResult: Equatable {
    let charsToDelete: Int
    let corrected: String
    let confidence: Double
    let source: CorrectionSource
}

struct CorrectionToken: Equatable {
    let original: String
    let correctionTarget: String
    let correctionTargetLowercased: String
    let leadingDecoration: String
    let trailingDecoration: String
}

struct PatternEvaluationContext: Equatable {
    let token: CorrectionToken
    let guesses: [String]
    let previousTokenLowercased: String?
    let isAtSentenceStart: Bool
}

enum SuggestionStrength: Int, Comparable {
    case helpfulAlternative = 1
    case strongRepair = 0

    static func < (lhs: SuggestionStrength, rhs: SuggestionStrength) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

struct PreparedCorrectionContext {
    let token: CorrectionToken
    let guesses: [String]
    let patternContext: PatternEvaluationContext
}

// MARK: - Autocorrection Engine

// Hybrid engine: deterministic typo fixes first, UITextChecker fallback second.
struct AutocorrectionEngine {
    let textChecker = UITextChecker()
    let suggestionProvider: any SuggestionProvider = HybridSuggestionProvider.shared
    private let minimumTextCheckerAutoApplyConfidence = 0.96

    // Keep this map intentionally small. The suggestion bar should grow mainly
    // through ranking and pattern logic rather than an endless typo pair list.
    private let deterministicCorrections: [String: String] = [
        // Transpositions
        "teh": "the",
        "helo": "hello",
        "adn": "and",
        "ot": "on",
        "taht": "that",
        "thier": "their",
        "becase": "because",
        "agian": "again",
        "chekc": "check",
        "anyhting": "anything",
        // Missing / extra letter classics
        "helllo": "hello",
        "recieve": "receive",
        "becuase": "because",
        "wierd": "weird",
        "actaully": "actually",
        "diffrent": "different",
        "intresting": "interesting",
        "usaully": "usually",
        "keeo": "keep",
        // Stable long-word misspellings
        "seperate": "separate",
        "definately": "definitely",
        "goverment": "government",
        "untill": "until",
        "enviroment": "environment",
        "tommorow": "tomorrow",
        "surprized": "surprised"
    ]

    func evaluate(context: String) -> AutocorrectionResult? {
        autoApplyCandidateResults(for: context)?.results.first
    }

    func suggestions(context: String, boostedTerms: [SuggestionBoostTerm] = []) -> AutocorrectionSuggestionSet? {
        guard let ranked = suggestionCandidateResults(for: context, boostedTerms: boostedTerms) else { return nil }

        let suggestions = ranked.results.prefix(2).map { result in
            AutocorrectionSuggestion(
                text: result.corrected,
                source: result.source,
                confidence: result.confidence
            )
        }

        guard !suggestions.isEmpty else { return nil }
        return AutocorrectionSuggestionSet(token: ranked.token, suggestions: Array(suggestions))
    }

    // MARK: - Tokenization

    static func lastToken(in context: String) -> CorrectionToken? {
        var token = ""
        for character in context.reversed() {
            if isTokenBoundary(character) {
                break
            }
            token = String(character) + token
        }

        guard !token.isEmpty else { return nil }

        let decorated = unwrapRoleplayDecoratedToken(token)
        return CorrectionToken(
            original: token,
            correctionTarget: decorated.core,
            correctionTargetLowercased: decorated.core.lowercased(),
            leadingDecoration: decorated.leadingDecoration,
            trailingDecoration: decorated.trailingDecoration
        )
    }

    static func applyCasePattern(from source: String, to corrected: String) -> String {
        if source == source.lowercased(), corrected.lowercased().hasPrefix("i'") {
            return corrected.prefix(1).uppercased() + corrected.dropFirst().lowercased()
        }

        if source == source.uppercased(), source.count > 1 {
            return corrected.uppercased()
        }

        if source.first?.isUppercase == true {
            return corrected.prefix(1).uppercased() + corrected.dropFirst().lowercased()
        }

        return corrected.lowercased()
    }

    private static func isTokenBoundary(_ character: Character) -> Bool {
        character == " " || character == "\n" || character == "\t"
    }

    // MARK: - Deterministic Fixes

    private func deterministicResult(for token: CorrectionToken) -> AutocorrectionResult? {
        if let exact = deterministicCorrections[token.correctionTargetLowercased] {
            return makeResult(
                for: token,
                correctedLowercased: exact,
                confidence: 0.99,
                source: .deterministicRule
            )
        }

        guard token.correctionTargetLowercased.count > 3 else { return nil }

        if let repeatedLetterFix = collapseRepeatedLetters(in: token.correctionTargetLowercased),
           repeatedLetterFix != token.correctionTargetLowercased,
           !hasExpressiveTrailingRepeat(token.correctionTargetLowercased),
           isDictionaryWord(repeatedLetterFix) {
            return makeResult(
                for: token,
                correctedLowercased: repeatedLetterFix,
                confidence: 0.95,
                source: .deterministicRule
            )
        }

        return nil
    }

    // MARK: - Token Gating

    private func shouldSkipStylizedToken(_ token: String) -> Bool {
        if hasExpressiveTrailingRepeat(token.lowercased()) {
            return true
        }

        return containsInteriorRoleplayMarker(token)
    }

    private func containsInteriorRoleplayMarker(_ token: String) -> Bool {
        guard token.count >= 3 else { return false }

        let markerSet: Set<Character> = ["*", "_", "~"]
        let interior = token.dropFirst().dropLast()
        return interior.contains { markerSet.contains($0) }
    }

    private static func unwrapRoleplayDecoratedToken(_ token: String) -> (core: String, leadingDecoration: String, trailingDecoration: String) {
        guard token.count >= 3,
              let first = token.first,
              let last = token.last,
              first == last,
              ["*", "_", "~"].contains(first) else {
            return (token, "", "")
        }

        let core = String(token.dropFirst().dropLast())
        guard !core.isEmpty else {
            return (token, "", "")
        }

        return (core, String(first), String(last))
    }

    // MARK: - Context Preparation

    private func makePatternContext(
        for token: CorrectionToken,
        in fullContext: String,
        guesses: [String]
    ) -> PatternEvaluationContext {
        let prefix = String(fullContext.dropLast(token.original.count))
        let previousContext = prefix.trimmingCharacters(in: .whitespacesAndNewlines)
        return PatternEvaluationContext(
            token: token,
            guesses: guesses,
            previousTokenLowercased: Self.lastToken(in: previousContext)?.correctionTargetLowercased,
            isAtSentenceStart: Self.isSentenceStartPrefix(prefix)
        )
    }

    private static func isSentenceStartPrefix(_ prefix: String) -> Bool {
        let trimmed = prefix.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let last = trimmed.last else { return true }
        return last == "." || last == "!" || last == "?" || last == "\n"
    }

    func preparedContext(for context: String, minimumTokenLength: Int = 2) -> PreparedCorrectionContext? {
        guard let token = Self.lastToken(in: context), token.original.count >= minimumTokenLength else { return nil }
        guard token.correctionTarget.count >= minimumTokenLength else { return nil }
        guard !shouldSkipStylizedToken(token.original) else { return nil }

        let guesses = textCheckerGuesses(for: token.correctionTarget).map { $0.lowercased() }
        return PreparedCorrectionContext(
            token: token,
            guesses: guesses,
            patternContext: makePatternContext(for: token, in: context, guesses: guesses)
        )
    }

    func baseCandidateResults(for prepared: PreparedCorrectionContext) -> [AutocorrectionResult] {
        [
            deterministicResult(for: prepared.token),
            patternResult(for: prepared.patternContext)
        ]
        .compactMap { $0 }
    }

    // MARK: - Result Construction

    func textCheckerResult(for token: CorrectionToken, guesses: [String]) -> AutocorrectionResult? {
        guard !shouldBlockTrailingDuplicateCorrection(input: token.correctionTargetLowercased, guesses: guesses) else {
            return nil
        }

        let acceptedGuesses = guesses
            .filter { candidate in
                shouldAcceptTextCheckerCandidate(input: token.correctionTargetLowercased, candidate: candidate)
            }

        guard let acceptedGuess = acceptedGuesses.min(by: { lhs, rhs in
            rank(lhs, against: token.correctionTargetLowercased) < rank(rhs, against: token.correctionTargetLowercased)
        }) else {
            return nil
        }

        return makeResult(
            for: token,
            correctedLowercased: acceptedGuess,
            confidence: confidenceScore(input: token.correctionTargetLowercased, candidate: acceptedGuess),
            source: .textChecker
        )
    }

    func makeResult(
        for token: CorrectionToken,
        correctedLowercased: String,
        confidence: Double,
        source: CorrectionSource
    ) -> AutocorrectionResult? {
        guard correctedLowercased != token.correctionTargetLowercased else { return nil }

        let correctedCore = Self.applyCasePattern(from: token.correctionTarget, to: correctedLowercased)

        return AutocorrectionResult(
            charsToDelete: token.original.count,
            corrected: token.leadingDecoration + correctedCore + token.trailingDecoration,
            confidence: confidence,
            source: source
        )
    }

    // MARK: - Auto-Apply Pipeline

    private func autoApplyCandidateResults(for context: String) -> (token: CorrectionToken, results: [AutocorrectionResult])? {
        guard let prepared = preparedContext(for: context) else { return nil }
        let baseCandidates = baseCandidateResults(for: prepared)

        let candidates: [AutocorrectionResult?] = baseCandidates.map { $0 } + [
            textCheckerResult(for: prepared.token, guesses: prepared.guesses).flatMap { result in
                result.confidence >= minimumTextCheckerAutoApplyConfidence ? result : nil
            }
        ]

        var seen = Set<String>()
        let uniqueResults = candidates
            .compactMap { $0 }
            .filter { result in
                let key = result.corrected.lowercased()
                return seen.insert(key).inserted
            }

        guard !uniqueResults.isEmpty else { return nil }
        return (prepared.token, uniqueResults)
    }

    // MARK: - Suggestion Pipeline

    func shouldAcceptTextCheckerCandidate(input: String, candidate: String) -> Bool {
        guard input.count >= 2, candidate != input else { return false }

        let distance = damerauLevenshteinDistance(input, candidate)
        if input.count <= 3 {
            return distance == 1 && isLikelyApostropheVariant(input: input, candidate: candidate)
        }

        if isLikelyApostropheVariant(input: input, candidate: candidate) {
            return true
        }

        if isSingleTransposition(input, candidate) {
            return true
        }

        if distance == 1 {
            return true
        }

        return distance == 2
            && input.count >= 5
            && abs(input.count - candidate.count) <= 1
            && hasSameOuterLetters(input, candidate)
            && CommonWordLexicon.contains(candidate)
    }

    // MARK: - Scoring

    func confidenceScore(input: String, candidate: String) -> Double {
        if isLikelyApostropheVariant(input: input, candidate: candidate) {
            return 0.98
        }

        if isSingleTransposition(input, candidate) {
            return 0.96
        }

        let distance = damerauLevenshteinDistance(input, candidate)
        switch distance {
        case 0: return 0
        case 1: return 0.93
        case 2: return input.count >= 5 ? 0.84 : 0.72
        default: return 0.5
        }
    }
}
