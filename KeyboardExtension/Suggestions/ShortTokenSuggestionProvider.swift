import Foundation

// MARK: - Short Token Entry

fileprivate struct ShortTokenEntry: Equatable {
    let prefix: String
    let candidate: String
    let score: Double
    let tags: Set<String>
}

// MARK: - Short Token Lexicon

final class ShortTokenLexicon {
    static let shared = ShortTokenLexicon()

    private final class BundleToken {}

    private let resourceName = "EnglishShortTokenLexicon"
    private let fallbackEntries: [ShortTokenEntry]
    private lazy var entriesByPrefix: [String: [ShortTokenEntry]] = Dictionary(
        grouping: loadEntries(),
        by: \.prefix
    ).mapValues { entries in
        entries.sorted {
            if $0.score != $1.score {
                return $0.score > $1.score
            }
            return $0.candidate < $1.candidate
        }
    }

    fileprivate init(fallbackEntries: [ShortTokenEntry]? = nil) {
        self.fallbackEntries = fallbackEntries ?? Self.defaultEntries
    }

    fileprivate func entries(for prefix: String) -> [ShortTokenEntry] {
        entriesByPrefix[prefix.lowercased()] ?? []
    }

    // MARK: - Loading

    private func loadEntries() -> [ShortTokenEntry] {
        guard let url = lexiconURL(),
              let content = try? String(contentsOf: url, encoding: .utf8) else {
            return fallbackEntries
        }

        let entries = content
            .split(whereSeparator: \.isNewline)
            .compactMap(Self.entry(from:))

        return entries.isEmpty ? fallbackEntries : entries
    }

    private func lexiconURL() -> URL? {
        let bundles = [Bundle.main, Bundle(for: BundleToken.self)] + Bundle.allBundles + Bundle.allFrameworks
        for bundle in bundles {
            if let url = bundle.url(forResource: resourceName, withExtension: "tsv") {
                return url
            }
        }
        return nil
    }

    nonisolated private static func entry(from line: Substring) -> ShortTokenEntry? {
        guard !line.hasPrefix("#") else { return nil }

        let parts = line.split(separator: "\t", omittingEmptySubsequences: false)
        guard parts.count >= 3,
              let score = Double(parts[2]) else {
            return nil
        }

        let tags = parts.count >= 4
            ? Set(parts[3].split(separator: ",").map { String($0).lowercased() })
            : []
        return ShortTokenEntry(
            prefix: String(parts[0]).lowercased(),
            candidate: String(parts[1]).lowercased(),
            score: score,
            tags: tags
        )
    }

    private static let defaultEntries: [ShortTokenEntry] = [
        ShortTokenEntry(prefix: "t", candidate: "the", score: 10000, tags: ["start", "mid"]),
        ShortTokenEntry(prefix: "t", candidate: "this", score: 9800, tags: ["start", "mid"]),
        ShortTokenEntry(prefix: "th", candidate: "the", score: 10000, tags: ["start", "mid"]),
        ShortTokenEntry(prefix: "th", candidate: "that", score: 9800, tags: ["mid"]),
        ShortTokenEntry(prefix: "th", candidate: "this", score: 9600, tags: ["start", "mid"]),
        ShortTokenEntry(prefix: "teh", candidate: "the", score: 10000, tags: ["repair"]),
        ShortTokenEntry(prefix: "adn", candidate: "and", score: 10000, tags: ["repair"]),
        ShortTokenEntry(prefix: "yur", candidate: "your", score: 10000, tags: ["repair"]),
        ShortTokenEntry(prefix: "yo", candidate: "you", score: 10000, tags: ["start", "mid"]),
        ShortTokenEntry(prefix: "yo", candidate: "your", score: 9800, tags: ["start", "mid"])
    ]
}

// MARK: - Short Token Suggestion Provider

struct ShortTokenSuggestionProvider: SuggestionProvider {
    static let shared = ShortTokenSuggestionProvider()

    private let lexicon: ShortTokenLexicon
    private let nextWordLexicon: NextWordLexicon

    init(
        lexicon: ShortTokenLexicon = .shared,
        nextWordLexicon: NextWordLexicon = .shared
    ) {
        self.lexicon = lexicon
        self.nextWordLexicon = nextWordLexicon
    }

    func candidates(
        for prepared: PreparedCorrectionContext,
        engine: AutocorrectionEngine,
        boostedTerms: [SuggestionBoostTerm]
    ) -> [(result: AutocorrectionResult, strength: SuggestionStrength)] {
        let input = prepared.token.correctionTargetLowercased
        guard (1...3).contains(input.count) else { return [] }

        let candidates = (
            curatedCandidates(for: prepared)
            + boostedCandidates(for: prepared, boostedTerms: boostedTerms)
        )
        .sorted()

        var seen = Set<String>()
        return candidates
            .filter { seen.insert($0.text).inserted }
            .prefix(8)
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

    private func curatedCandidates(for prepared: PreparedCorrectionContext) -> [ShortTokenCandidate] {
        let input = prepared.token.correctionTargetLowercased
        return lexicon.entries(for: input).compactMap { entry in
            guard contextAllows(entry, context: prepared.patternContext) else { return nil }

            let contextBoost = nextWordBoost(
                for: entry.candidate,
                previousToken: prepared.patternContext.previousTokenLowercased
            )
            let sentenceBoost = prepared.patternContext.isAtSentenceStart && entry.tags.contains("start") ? 700.0 : 0
            let repairBoost = entry.tags.contains("repair") ? 1_200.0 : 0
            let finalScore = entry.score + contextBoost + sentenceBoost + repairBoost

            return ShortTokenCandidate(
                text: entry.candidate,
                source: .shortTokenLexicon,
                strength: entry.tags.contains("repair") ? .strongRepair : .helpfulAlternative,
                score: finalScore,
                confidence: confidence(for: finalScore, isRepair: entry.tags.contains("repair"))
            )
        }
    }

    private func boostedCandidates(
        for prepared: PreparedCorrectionContext,
        boostedTerms: [SuggestionBoostTerm]
    ) -> [ShortTokenCandidate] {
        let input = prepared.token.correctionTargetLowercased
        guard input.count >= 3 else { return [] }

        return boostedTerms.compactMap { term in
            guard term.source == .personalDictionary else { return nil }

            let word = term.word.lowercased()
            guard word != input, word.hasPrefix(input) else { return nil }
            return ShortTokenCandidate(
                text: word,
                source: .personalDictionary,
                strength: .strongRepair,
                score: 12_000,
                confidence: 0.96
            )
        }
    }

    // MARK: - Ranking Helpers

    private func contextAllows(_ entry: ShortTokenEntry, context: PatternEvaluationContext) -> Bool {
        if entry.tags.contains("repair") {
            return true
        }

        if context.isAtSentenceStart {
            return entry.tags.isEmpty || entry.tags.contains("start")
        }

        return entry.tags.isEmpty || entry.tags.contains("mid")
    }

    private func nextWordBoost(for candidate: String, previousToken: String?) -> Double {
        guard let previousToken else { return 0 }

        guard let score = nextWordLexicon
            .entries(for: previousToken)
            .first(where: { $0.candidate.lowercased() == candidate })?
            .score else {
            return 0
        }

        return min(score * 0.28, 2_800)
    }

    private func confidence(for score: Double, isRepair: Bool) -> Double {
        let base = isRepair ? 0.74 : 0.58
        return min(0.97, base + score / 40_000)
    }
}

// MARK: - Short Token Candidate

private struct ShortTokenCandidate: Comparable {
    let text: String
    let source: CorrectionSource
    let strength: SuggestionStrength
    let score: Double
    let confidence: Double

    static func < (lhs: ShortTokenCandidate, rhs: ShortTokenCandidate) -> Bool {
        if lhs.strength != rhs.strength {
            return lhs.strength < rhs.strength
        }
        if lhs.source != rhs.source {
            return sourceRank(lhs.source) < sourceRank(rhs.source)
        }
        if lhs.score != rhs.score {
            return lhs.score > rhs.score
        }
        return lhs.text < rhs.text
    }

    private static func sourceRank(_ source: CorrectionSource) -> Int {
        switch source {
        case .personalDictionary:
            return 0
        case .shortTokenLexicon:
            return 1
        default:
            return 2
        }
    }
}
