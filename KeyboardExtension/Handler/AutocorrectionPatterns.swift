import UIKit

extension AutocorrectionEngine {
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

    func patternResult(for token: CorrectionToken, guesses: [String]) -> AutocorrectionResult? {
        if let generatedNearbyKeyCandidate = generatedNearbyKeyCandidate(input: token.correctionTargetLowercased) {
            return makeResult(
                for: token,
                correctedLowercased: generatedNearbyKeyCandidate,
                confidence: 0.97,
                source: CorrectionSource.deterministicRule
            )
        }

        if let nearbyKeyCandidate = nearbyKeySubstitutionCandidate(input: token.correctionTargetLowercased, guesses: guesses) {
            return makeResult(
                for: token,
                correctedLowercased: nearbyKeyCandidate,
                confidence: 0.97,
                source: CorrectionSource.deterministicRule
            )
        }

        if let trailingDuplicateCandidate = unambiguousTrailingDuplicateCandidate(input: token.correctionTargetLowercased, guesses: guesses) {
            return makeResult(
                for: token,
                correctedLowercased: trailingDuplicateCandidate,
                confidence: 0.96,
                source: CorrectionSource.deterministicRule
            )
        }

        return nil
    }

    func generatedNearbyKeyCandidate(input: String) -> String? {
        guard (3...4).contains(input.count) else { return nil }

        let inputChars = Array(input)
        var candidates = Set<String>()
        let index = inputChars.startIndex

        guard let neighbors = Self.keyboardNeighborMap[inputChars[index]] else { return nil }

        for neighbor in neighbors {
            var candidateChars = inputChars
            candidateChars[index] = neighbor
            let candidate = String(candidateChars)

            guard candidate != input else { continue }
            guard CommonWordLexicon.contains(candidate) else { continue }
            candidates.insert(candidate)
        }

        guard !candidates.isEmpty else { return nil }

        let ranked = candidates.map { candidate in
            (candidate, rank(candidate, against: input))
        }

        guard let best = ranked.min(by: { lhs, rhs in lhs.1 < rhs.1 }) else { return nil }
        let topMatches = ranked.filter { $0.1 == best.1 }
        guard topMatches.count == 1 else { return nil }

        return best.0
    }

    func nearbyKeySubstitutionCandidate(input: String, guesses: [String]) -> String? {
        let accepted = guesses.filter { candidate in
            isNearbyKeySubstitution(input: input, candidate: candidate)
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
                return guesses.first(where: { candidate in
                    topMatches.contains { $0.0 == candidate }
                })
            }
        }

        return best.0
    }

    func isNearbyKeySubstitution(input: String, candidate: String) -> Bool {
        guard input.count == candidate.count, input.count >= 3 else { return false }

        let inputChars = Array(input)
        let candidateChars = Array(candidate)
        let mismatchedIndexes = inputChars.indices.filter { inputChars[$0] != candidateChars[$0] }
        guard mismatchedIndexes.count == 1, let mismatch = mismatchedIndexes.first else { return false }

        let typed = inputChars[mismatch]
        let corrected = candidateChars[mismatch]
        return Self.keyboardNeighborMap[typed]?.contains(corrected) == true
    }

    func unambiguousTrailingDuplicateCandidate(input: String, guesses: [String]) -> String? {
        guard input.count >= 5 else { return nil }
        guard let last = input.last else { return nil }
        guard input.suffix(2).allSatisfy({ $0 == last }) else { return nil }
        guard !shouldBlockTrailingDuplicateCorrection(input: input, guesses: guesses) else { return nil }

        let collapsed = String(input.dropLast())
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
