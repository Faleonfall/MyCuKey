import UIKit

// MARK: - Pattern Buckets

extension AutocorrectionEngine {
    private static let trustedMediumCorrections: [String: String] = [
        "yur": "your",
        "okey": "okay"
    ]

    private static let mergedTokenCorrections: [String: String] = [
        "noone": "no one",
        "alot": "a lot"
    ]

    private static let apostropheRepairCandidates: [String] = [
        "here's",
        "that's",
        "what's",
        "where's",
        "there's",
        "who's",
        "it's"
    ]

    private static let keyboardNeighborMap: [Character: Set<Character>] = [
        "a": ["q", "w", "s", "z"],
        "b": ["v", "g", "h", "n"],
        "c": ["x", "d", "f", "v"],
        "d": ["s", "e", "r", "f", "c", "x"],
        "e": ["w", "s", "d", "r"],
        "f": ["d", "r", "t", "g", "v", "c"],
        "g": ["f", "t", "y", "h", "b", "v"],
        "h": ["g", "y", "u", "j", "n", "b"],
        "i": ["u", "j", "k", "o"],
        "j": ["h", "u", "i", "k", "m", "n"],
        "k": ["j", "i", "o", "l", "m"],
        "l": ["k", "o", "p"],
        "m": ["n", "j", "k"],
        "n": ["b", "h", "j", "m"],
        "o": ["i", "k", "l", "p"],
        "p": ["o", "l"],
        "q": ["w", "a"],
        "r": ["e", "d", "f", "t"],
        "s": ["a", "w", "e", "d", "x", "z"],
        "t": ["r", "f", "g", "y"],
        "u": ["y", "h", "j", "i"],
        "v": ["c", "f", "g", "b"],
        "w": ["q", "a", "s", "e"],
        "x": ["z", "s", "d", "c"],
        "y": ["t", "g", "h", "u"],
        "z": ["a", "s", "x"]
    ]

    func patternResult(for context: PatternEvaluationContext) -> AutocorrectionResult? {
        if let trustedMediumCandidate = trustedMediumCandidate(input: context.token.correctionTargetLowercased) {
            return makeResult(
                for: context.token,
                correctedLowercased: trustedMediumCandidate,
                confidence: 0.98,
                source: CorrectionSource.deterministicRule
            )
        }

        if let mergedTokenCandidate = mergedTokenCandidate(input: context.token.correctionTargetLowercased) {
            return makeResult(
                for: context.token,
                correctedLowercased: mergedTokenCandidate,
                confidence: 0.98,
                source: CorrectionSource.deterministicRule
            )
        }

        if let apostropheRepairCandidate = apostropheRepairCandidate(for: context) {
            return makeResult(
                for: context.token,
                correctedLowercased: apostropheRepairCandidate,
                confidence: 0.97,
                source: CorrectionSource.deterministicRule
            )
        }

        if let generatedNearbyKeyCandidate = generatedNearbyKeyCandidate(input: context.token.correctionTargetLowercased) {
            return makeResult(
                for: context.token,
                correctedLowercased: generatedNearbyKeyCandidate,
                confidence: 0.97,
                source: CorrectionSource.deterministicRule
            )
        }

        if let nearbyKeyCandidate = nearbyKeySubstitutionCandidate(context: context) {
            return makeResult(
                for: context.token,
                correctedLowercased: nearbyKeyCandidate,
                confidence: 0.97,
                source: CorrectionSource.deterministicRule
            )
        }

        if let trailingDuplicateCandidate = unambiguousTrailingDuplicateCandidate(input: context.token.correctionTargetLowercased, guesses: context.guesses) {
            return makeResult(
                for: context.token,
                correctedLowercased: trailingDuplicateCandidate,
                confidence: 0.96,
                source: CorrectionSource.deterministicRule
            )
        }

        return nil
    }

    // MARK: - Curated Safe Repairs

    func trustedMediumCandidate(input: String) -> String? {
        Self.trustedMediumCorrections[input]
    }

    func mergedTokenCandidate(input: String) -> String? {
        Self.mergedTokenCorrections[input]
    }

    // MARK: - Contextual Repairs

    func apostropheRepairCandidate(for context: PatternEvaluationContext) -> String? {
        let input = context.token.correctionTargetLowercased
        guard !CommonWordLexicon.contains(input) else { return nil }
        guard context.isAtSentenceStart || context.previousTokenLowercased == "you" else { return nil }

        let candidates = Self.apostropheRepairCandidates.filter { candidate in
            let unwrapped = candidate.replacingOccurrences(of: "'", with: "")
            guard hasSameOuterLetters(input, unwrapped) else { return false }
            return damerauLevenshteinDistance(input, unwrapped) == 1
        }

        guard candidates.count == 1 else { return nil }
        return candidates.first
    }

    // MARK: - Nearby-Key Repairs

    func generatedNearbyKeyCandidate(input: String) -> String? {
        guard input.count == 3 else { return nil }
        guard !CommonWordLexicon.contains(input) else { return nil }

        let ranked = CommonWordLexicon.words.compactMap { candidate -> (String, (Int, Int, Int, Int, Int))? in
            guard candidate.count == input.count else { return nil }
            guard isSafeMediumLengthRescue(input: input, candidate: candidate) else { return nil }
            return (candidate, rank(candidate, against: input))
        }

        guard !ranked.isEmpty else { return nil }
        guard let best = ranked.min(by: { lhs, rhs in lhs.1 < rhs.1 }) else { return nil }
        let topMatches = ranked.filter { $0.1 == best.1 }
        guard topMatches.count == 1 else { return nil }

        return best.0
    }

    func isSafeMediumLengthRescue(input: String, candidate: String) -> Bool {
        let distance = damerauLevenshteinDistance(input, candidate)
        guard distance <= 2 else { return false }
        if input.count > 3 {
            guard hasStrongShapeAgreement(input: input, candidate: candidate) else { return false }
        }
        return isLeadingNearbyKeySubstitution(input: input, candidate: candidate)
    }

    func hasStrongShapeAgreement(input: String, candidate: String) -> Bool {
        if hasSameOuterLetters(input, candidate) {
            return true
        }

        let prefixLength = commonPrefixLength(input, candidate)
        return prefixLength >= max(2, min(input.count, candidate.count) - 2)
    }

    func isLeadingNearbyKeySubstitution(input: String, candidate: String) -> Bool {
        guard input.count == candidate.count, input.count >= 3 else { return false }

        let inputChars = Array(input)
        let candidateChars = Array(candidate)
        let mismatchedIndexes = inputChars.indices.filter { inputChars[$0] != candidateChars[$0] }
        guard mismatchedIndexes.count == 1, mismatchedIndexes.first == inputChars.startIndex else { return false }

        let typed = inputChars[inputChars.startIndex]
        let corrected = candidateChars[candidateChars.startIndex]
        return Self.keyboardNeighborMap[typed]?.contains(corrected) == true
    }

    func nearbyKeySubstitutionCandidate(context: PatternEvaluationContext) -> String? {
        let input = context.token.correctionTargetLowercased
        guard !CommonWordLexicon.contains(input) else { return nil }
        guard !(input.count >= 4 && isDictionaryWord(input)) else { return nil }

        let accepted = context.guesses.filter { candidate in
            isLeadingNearbyKeySubstitution(input: input, candidate: candidate)
                && CommonWordLexicon.contains(candidate)
        }

        guard !accepted.isEmpty else { return nil }

        let ranked = accepted.map { candidate in
            (candidate, rank(candidate, against: input))
        }

        guard let best = ranked.min(by: { lhs, rhs in lhs.1 < rhs.1 }) else { return nil }

        if input.count <= 4 {
            let topMatches = ranked.filter { $0.1 == best.1 }
            if topMatches.count > 1 {
                return context.guesses.first(where: { candidate in
                    topMatches.contains { $0.0 == candidate }
                })
            }
        }

        return best.0
    }

    // MARK: - Duplicate Handling

    func unambiguousTrailingDuplicateCandidate(input: String, guesses: [String]) -> String? {
        guard input.count >= 5 else { return nil }
        guard let last = input.last else { return nil }
        guard input.suffix(2).allSatisfy({ $0 == last }) else { return nil }
        guard !shouldBlockTrailingDuplicateCorrection(input: input, guesses: guesses) else { return nil }

        let collapsed = String(input.dropLast())
        guard collapsed.count >= 5 else { return nil }
        guard CommonWordLexicon.contains(collapsed) else { return nil }

        let accepted = guesses.filter { $0 == collapsed }
        guard accepted.count == 1 else { return nil }
        return accepted.first
    }

    func shouldBlockTrailingDuplicateCorrection(input: String, guesses: [String]) -> Bool {
        guard input.count >= 5 else { return false }
        guard let last = input.last, input.suffix(2).allSatisfy({ $0 == last }) else { return false }

        let collapsed = String(input.dropLast())
        let plausibleAlternatives = Set(
            guesses.filter { candidate in
                if candidate == collapsed {
                    return true
                }

                let unwrapped = candidate.replacingOccurrences(of: "'", with: "")
                return commonPrefixLength(unwrapped, collapsed) >= max(3, collapsed.count - 1)
            }
        )

        return plausibleAlternatives.count > 1
    }
}
