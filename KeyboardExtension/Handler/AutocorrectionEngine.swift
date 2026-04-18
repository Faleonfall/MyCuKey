import UIKit

enum CorrectionSource: Equatable {
    case contraction
    case deterministicRule
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

// MARK: - Autocorrection Engine
// Hybrid engine: deterministic typo fixes first, UITextChecker fallback second.
struct AutocorrectionEngine {
    let textChecker = UITextChecker()
    private let minimumTextCheckerAutoApplyConfidence = 0.96

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

    func suggestions(context: String) -> AutocorrectionSuggestionSet? {
        guard let ranked = suggestionCandidateResults(for: context) else { return nil }

        let suggestions = ranked.results.prefix(2).map { result in
            AutocorrectionSuggestion(
                text: result.corrected,
                source: result.source,
                confidence: result.confidence,
                kind: .candidate
            )
        }

        guard !suggestions.isEmpty else { return nil }
        return AutocorrectionSuggestionSet(token: ranked.token, suggestions: Array(suggestions))
    }

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

    private func makePatternContext(
        for token: CorrectionToken,
        in fullContext: String,
        guesses: [String]
    ) -> PatternEvaluationContext {
        let prefix = String(fullContext.dropLast(token.original.count))
        return PatternEvaluationContext(
            token: token,
            guesses: guesses,
            previousTokenLowercased: Self.lastToken(in: prefix)?.correctionTargetLowercased,
            isAtSentenceStart: Self.isSentenceStartPrefix(prefix)
        )
    }

    private static func isSentenceStartPrefix(_ prefix: String) -> Bool {
        let trimmed = prefix.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let last = trimmed.last else { return true }
        return last == "." || last == "!" || last == "?" || last == "\n"
    }

    private func textCheckerResult(for token: CorrectionToken, guesses: [String]) -> AutocorrectionResult? {
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

    private func autoApplyCandidateResults(for context: String) -> (token: CorrectionToken, results: [AutocorrectionResult])? {
        guard let token = Self.lastToken(in: context), token.original.count >= 2 else { return nil }
        guard token.correctionTarget.count > 1 else { return nil }
        guard !shouldSkipStylizedToken(token.original) else { return nil }

        let lowercasedGuesses = textCheckerGuesses(for: token.correctionTarget)
            .map { $0.lowercased() }

        let patternContext = makePatternContext(
            for: token,
            in: context,
            guesses: lowercasedGuesses
        )

        let candidates: [AutocorrectionResult?] = [
            deterministicResult(for: token),
            patternResult(for: patternContext),
            textCheckerResult(for: token, guesses: lowercasedGuesses).flatMap { result in
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
        return (token, uniqueResults)
    }

    private func suggestionCandidateResults(for context: String) -> (token: CorrectionToken, results: [AutocorrectionResult])? {
        guard let token = Self.lastToken(in: context), token.original.count >= 2 else { return nil }
        guard token.correctionTarget.count > 1 else { return nil }
        guard !shouldSkipStylizedToken(token.original) else { return nil }

        let lowercasedGuesses = textCheckerGuesses(for: token.correctionTarget)
            .map { $0.lowercased() }

        let patternContext = makePatternContext(
            for: token,
            in: context,
            guesses: lowercasedGuesses
        )

        var candidates = [AutocorrectionResult]()

        if let deterministic = deterministicResult(for: token) {
            candidates.append(deterministic)
        }

        if let pattern = patternResult(for: patternContext) {
            candidates.append(pattern)
        }

        candidates.append(contentsOf: suggestionTextCheckerResults(for: token, guesses: lowercasedGuesses))

        var seen = Set<String>()
        let uniqueResults = candidates.filter { result in
            let key = result.corrected.lowercased()
            return seen.insert(key).inserted
        }

        guard !uniqueResults.isEmpty else { return nil }
        return (token, Array(uniqueResults.prefix(2)))
    }

    private func suggestionTextCheckerResults(for token: CorrectionToken, guesses: [String]) -> [AutocorrectionResult] {
        guard !shouldBlockTrailingDuplicateCorrection(input: token.correctionTargetLowercased, guesses: guesses) else {
            return []
        }

        let orderedGuesses = orderedSuggestionGuesses(
            input: token.correctionTargetLowercased,
            guesses: guesses
        )

        return orderedGuesses.compactMap { guess in
            makeResult(
                for: token,
                correctedLowercased: guess,
                confidence: confidenceScore(input: token.correctionTargetLowercased, candidate: guess),
                source: .textChecker
            )
        }
    }

    private func orderedSuggestionGuesses(input: String, guesses: [String]) -> [String] {
        let filtered = guesses.filter { candidate in
            shouldAcceptSuggestionCandidate(input: input, candidate: candidate)
        }

        return filtered.sorted { lhs, rhs in
            let lhsRank = rank(lhs, against: input)
            let rhsRank = rank(rhs, against: input)
            if lhsRank == rhsRank {
                return guesses.firstIndex(of: lhs) ?? .max < guesses.firstIndex(of: rhs) ?? .max
            }
            return lhsRank < rhsRank
        }
    }

    private func shouldAcceptTextCheckerCandidate(input: String, candidate: String) -> Bool {
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

    private func shouldAcceptSuggestionCandidate(input: String, candidate: String) -> Bool {
        guard input.count >= 2, candidate != input else { return false }

        if shouldAcceptTextCheckerCandidate(input: input, candidate: candidate) {
            return true
        }

        guard input.count >= 3 else { return false }

        let distance = damerauLevenshteinDistance(input, candidate)
        guard distance <= 3 else { return false }

        if isLikelyApostropheVariant(input: input, candidate: candidate) {
            return true
        }

        let isWordCandidate = CommonWordLexicon.contains(candidate) || isDictionaryWord(candidate)
        guard isWordCandidate else { return false }

        if input.count <= 4 {
            return distance <= 2
        }

        if distance == 1 {
            return true
        }

        if distance == 2 {
            return hasSameOuterLetters(input, candidate)
                || commonPrefixLength(input, candidate) >= 1
                || isSubsequence(input, of: candidate)
                || isSubsequence(candidate, of: input)
        }

        return input.count >= 6
            && (hasSameOuterLetters(input, candidate)
                || commonPrefixLength(input, candidate) >= 2)
    }

    private func confidenceScore(input: String, candidate: String) -> Double {
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
