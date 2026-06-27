import Foundation

// MARK: - Local Suggestion Provider

struct LocalSuggestionProvider: SuggestionProvider {
    static let shared = LocalSuggestionProvider()

    private let index: SuggestionCandidateIndex

    init(index: SuggestionCandidateIndex = .shared) {
        self.index = index
    }

    func candidates(
        for prepared: PreparedCorrectionContext,
        engine: AutocorrectionEngine,
        boostedTerms: [SuggestionBoostTerm]
    ) -> [(result: AutocorrectionResult, strength: SuggestionStrength)] {
        let input = prepared.token.correctionTargetLowercased
        var candidates: [SuggestionCandidate] = []

        candidates.append(contentsOf: boostedCandidates(
            input: input,
            boostedTerms: boostedTerms,
            engine: engine
        ))

        candidates.append(contentsOf: prefixCandidates(
            for: prepared,
            engine: engine
        ))

        candidates.append(contentsOf: lexiconRepairCandidates(
            input: input,
            engine: engine
        ))

        return candidates
            .sorted()
            .prefix(24)
            .compactMap { candidate in
                guard let result = engine.makeResult(
                    for: prepared.token,
                    correctedLowercased: candidate.text,
                    confidence: candidate.confidence,
                    source: candidate.source
                ) else {
                    return nil
                }
                return (result: result, strength: candidate.strength)
            }
    }

    // MARK: - Candidate Sources

    private func boostedCandidates(
        input: String,
        boostedTerms: [SuggestionBoostTerm],
        engine: AutocorrectionEngine
    ) -> [SuggestionCandidate] {
        boostedTerms.compactMap { term in
            let word = term.word.lowercased()
            guard shouldConsiderBoostedTerm(
                input: input,
                word: word,
                source: term.source,
                engine: engine
            ) else {
                return nil
            }

            let isPrefixCompletion = word.hasPrefix(input)
            // Learned/system prefix matches are completions, not typo repairs, so
            // their full length should not bury them below generic dictionary words.
            let distance = isPrefixCompletion
                ? max(1, min(2, word.count - input.count))
                : engine.damerauLevenshteinDistance(input, word)
            return rankedCandidate(
                input: input,
                word: word,
                source: term.source,
                distance: distance,
                frequencyScore: 9_800,
                sourceBoost: 0.22,
                forcedStrength: isPrefixCompletion ? .strongRepair : nil,
                engine: engine
            )
        }
    }

    private func prefixCandidates(for prepared: PreparedCorrectionContext, engine: AutocorrectionEngine) -> [SuggestionCandidate] {
        let input = prepared.token.correctionTargetLowercased
        guard input.count <= 3 else { return [] }

        return index.prefixCandidates(for: input, limit: 24).compactMap { entry in
            guard entry.word != input else { return nil }
            let sentenceStarterPriority = sentenceStarterPriority(
                for: entry.word,
                context: prepared.patternContext
            )
            if prepared.patternContext.isAtSentenceStart,
               input.count <= 2,
               sentenceStarterPriority == nil {
                return nil
            }

            let contextBoost = sentenceStarterPriority.map { Double(20 - $0) * 0.015 } ?? 0.04
            let confidence = sentenceStarterPriority.map { priority in
                max(0.70, 0.94 - Double(priority) * 0.004)
            } ?? min(0.91, 0.56 + entry.score / 24_000 + Double(input.count) * 0.06)
            return SuggestionCandidate(
                text: entry.word,
                source: .localLexicon,
                strength: .helpfulAlternative,
                confidence: confidence,
                distance: max(1, entry.word.count - input.count),
                frequencyScore: entry.score,
                keyboardNeighborScore: 0,
                prefixLength: input.count,
                contextBoost: contextBoost
            )
        }
    }

    private func lexiconRepairCandidates(input: String, engine: AutocorrectionEngine) -> [SuggestionCandidate] {
        guard input.count >= 3 else { return [] }

        let maximumDistance = engine.maximumSuggestionDistance(for: input)
        return index
            .editCandidates(for: input, maximumDistance: maximumDistance)
            .compactMap { entry in
                guard shouldConsiderLexiconCandidate(input: input, candidate: entry.word, engine: engine) else {
                    return nil
                }

                let distance = engine.damerauLevenshteinDistance(input, entry.word)
                guard distance > 0, distance <= maximumDistance else { return nil }

                return rankedCandidate(
                    input: input,
                    word: entry.word,
                    source: .localLexicon,
                    distance: distance,
                    frequencyScore: entry.score,
                    sourceBoost: 0,
                    engine: engine
                )
            }
    }

    // MARK: - Acceptance

    private func shouldConsiderBoostedTerm(
        input: String,
        word: String,
        source: CorrectionSource,
        engine: AutocorrectionEngine
    ) -> Bool {
        guard input.count >= 1, word != input else { return false }

        if source == .supplementaryLexicon {
            guard input.count >= 4 else { return false }
        }

        if word.hasPrefix(input), input.count <= 4 { return true }

        let distance = engine.damerauLevenshteinDistance(input, word)
        return distance <= engine.maximumSuggestionDistance(for: input)
            && strongShapeMatch(input: input, candidate: word, engine: engine)
    }

    private func shouldConsiderLexiconCandidate(input: String, candidate: String, engine: AutocorrectionEngine) -> Bool {
        guard candidate != input else { return false }

        if input.count <= 3, candidate.count < input.count {
            return false
        }

        if input.count <= 4 {
            return true
        }

        return strongShapeMatch(input: input, candidate: candidate, engine: engine)
            || characterOverlapRatio(input, candidate) >= 0.58
    }

    private func strongShapeMatch(input: String, candidate: String, engine: AutocorrectionEngine) -> Bool {
        engine.hasSameOuterLetters(input, candidate)
            || engine.commonPrefixLength(input, candidate) >= min(3, input.count)
            || engine.isSubsequence(input, of: candidate)
            || engine.isSubsequence(candidate, of: input)
    }

    private func sentenceStarterPriority(
        for word: String,
        context: PatternEvaluationContext
    ) -> Int? {
        guard context.isAtSentenceStart else { return nil }
        let starters = [
            "the",
            "this",
            "i",
            "you",
            "we",
            "it",
            "that",
            "they",
            "there",
            "what",
            "how",
            "where",
            "why"
        ]
        return starters.firstIndex(of: word)
    }

    // MARK: - Ranking

    private func rankedCandidate(
        input: String,
        word: String,
        source: CorrectionSource,
        distance: Int,
        frequencyScore: Double,
        sourceBoost: Double,
        forcedStrength: SuggestionStrength? = nil,
        engine: AutocorrectionEngine
    ) -> SuggestionCandidate {
        let keyboardNeighborScore = engine.keyboardNeighborSubstitutionCount(input: input, candidate: word)
        let prefixLength = engine.commonPrefixLength(input, word)
        let shapeBoost = engine.hasSameOuterLetters(input, word) ? 0.05 : 0
        let prefixBoost = min(Double(prefixLength) * 0.025, 0.12)
        let neighborBoost = min(Double(keyboardNeighborScore) * 0.04, 0.12)
        let frequencyBoost = min(frequencyScore / 25_000, 0.34)
        let distancePenalty = Double(distance) * 0.085

        let confidence = max(
            0.44,
            min(0.97, 0.58 + frequencyBoost + shapeBoost + prefixBoost + neighborBoost + sourceBoost - distancePenalty)
        )

        let strength: SuggestionStrength = forcedStrength ?? {
            if distance <= 1 || engine.isSingleTransposition(input, word) {
                return .strongRepair
            }
            if input.count >= 6, distance <= 3, strongShapeMatch(input: input, candidate: word, engine: engine) {
                return .strongRepair
            }
            return .helpfulAlternative
        }()

        return SuggestionCandidate(
            text: word,
            source: source,
            strength: strength,
            confidence: confidence,
            distance: distance,
            frequencyScore: frequencyScore,
            keyboardNeighborScore: keyboardNeighborScore,
            prefixLength: prefixLength,
            contextBoost: sourceBoost
        )
    }

    private func characterOverlapRatio(_ lhs: String, _ rhs: String) -> Double {
        var rhsCounts: [Character: Int] = [:]
        for character in rhs {
            rhsCounts[character, default: 0] += 1
        }

        var overlap = 0
        for character in lhs {
            guard let count = rhsCounts[character], count > 0 else { continue }
            overlap += 1
            rhsCounts[character] = count - 1
        }

        return Double(overlap) / Double(max(lhs.count, rhs.count))
    }
}

// MARK: - Suggestion Candidate

private struct SuggestionCandidate: Comparable {
    let text: String
    let source: CorrectionSource
    let strength: SuggestionStrength
    let confidence: Double
    let distance: Int
    let frequencyScore: Double
    let keyboardNeighborScore: Int
    let prefixLength: Int
    let contextBoost: Double

    static func < (lhs: SuggestionCandidate, rhs: SuggestionCandidate) -> Bool {
        if lhs.strength != rhs.strength {
            return lhs.strength < rhs.strength
        }
        if lhs.confidence != rhs.confidence {
            return lhs.confidence > rhs.confidence
        }
        if lhs.distance != rhs.distance {
            return lhs.distance < rhs.distance
        }
        if lhs.contextBoost != rhs.contextBoost {
            return lhs.contextBoost > rhs.contextBoost
        }
        if lhs.frequencyScore != rhs.frequencyScore {
            return lhs.frequencyScore > rhs.frequencyScore
        }
        if lhs.keyboardNeighborScore != rhs.keyboardNeighborScore {
            return lhs.keyboardNeighborScore > rhs.keyboardNeighborScore
        }
        if lhs.prefixLength != rhs.prefixLength {
            return lhs.prefixLength > rhs.prefixLength
        }
        return lhs.text < rhs.text
    }
}
