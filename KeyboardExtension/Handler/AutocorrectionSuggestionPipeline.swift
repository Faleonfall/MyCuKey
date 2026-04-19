import UIKit

// MARK: - Suggestion Pipeline

extension AutocorrectionEngine {
    func suggestionCandidateResults(for context: String) -> (token: CorrectionToken, results: [AutocorrectionResult])? {
        guard let prepared = preparedContext(for: context) else { return nil }

        var rankedCandidates = baseCandidateResults(for: prepared).map { result in
            (result: result, strength: SuggestionStrength.strongRepair)
        }
        rankedCandidates.append(contentsOf: suggestionTextCheckerResults(for: prepared.token, guesses: prepared.guesses))

        var seen = Set<String>()
        let uniqueResults = rankedCandidates
            .filter { candidate in
                let key = candidate.result.corrected.lowercased()
                return seen.insert(key).inserted
            }
            .sorted { lhs, rhs in
                if lhs.strength != rhs.strength {
                    return lhs.strength < rhs.strength
                }
                if lhs.result.confidence != rhs.result.confidence {
                    return lhs.result.confidence > rhs.result.confidence
                }
                return rank(lhs.result.corrected.lowercased(), against: prepared.token.correctionTargetLowercased)
                    < rank(rhs.result.corrected.lowercased(), against: prepared.token.correctionTargetLowercased)
            }
            .map(\.result)
            .filter { $0.corrected.lowercased() != prepared.token.original.lowercased() }

        guard !uniqueResults.isEmpty else { return nil }
        return (prepared.token, Array(uniqueResults.prefix(2)))
    }

    func suggestionTextCheckerResults(for token: CorrectionToken, guesses: [String]) -> [(result: AutocorrectionResult, strength: SuggestionStrength)] {
        guard !shouldBlockTrailingDuplicateCorrection(input: token.correctionTargetLowercased, guesses: guesses) else {
            return []
        }

        let orderedGuesses = orderedSuggestionGuesses(
            input: token.correctionTargetLowercased,
            guesses: guesses
        )

        return orderedGuesses.compactMap { guess in
            guard let result = makeResult(
                for: token,
                correctedLowercased: guess,
                confidence: confidenceScore(input: token.correctionTargetLowercased, candidate: guess),
                source: .textChecker
            ) else {
                return nil
            }

            return (result: result, strength: suggestionStrength(input: token.correctionTargetLowercased, candidate: guess))
        }
    }

    func orderedSuggestionGuesses(input: String, guesses: [String]) -> [String] {
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

    func shouldAcceptSuggestionCandidate(input: String, candidate: String) -> Bool {
        guard input.count >= 2, candidate != input else { return false }

        if shouldAcceptTextCheckerCandidate(input: input, candidate: candidate) {
            return true
        }

        guard input.count >= 3 else { return false }

        let distance = damerauLevenshteinDistance(input, candidate)
        guard distance <= maximumSuggestionDistance(for: input) else { return false }

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
            && (
                hasSameOuterLetters(input, candidate)
                || commonPrefixLength(input, candidate) >= 2
                || strongSuggestionShapeMatch(input: input, candidate: candidate)
            )
    }

    func maximumSuggestionDistance(for input: String) -> Int {
        if input.count >= 8 { return 4 }
        if input.count >= 5 { return 3 }
        return 2
    }

    func strongSuggestionShapeMatch(input: String, candidate: String) -> Bool {
        hasSameOuterLetters(input, candidate)
            || commonPrefixLength(input, candidate) >= 3
            || isSubsequence(input, of: candidate)
            || isSubsequence(candidate, of: input)
    }

    // Suggestion slots can be broader than silent autocorrect because they ask
    // the user instead of overriding their text.
    func suggestionStrength(input: String, candidate: String) -> SuggestionStrength {
        if shouldAcceptTextCheckerCandidate(input: input, candidate: candidate) {
            return .strongRepair
        }

        let distance = damerauLevenshteinDistance(input, candidate)
        if distance <= 1 || isSingleTransposition(input, candidate) || isLikelyApostropheVariant(input: input, candidate: candidate) {
            return .strongRepair
        }

        return .helpfulAlternative
    }
}
