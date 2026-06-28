import Foundation

// MARK: - Unified Decoder

// Noisy-channel decoder over the WordTrie: unigram log-frequency minus edit
// cost, with protect-in-vocab and an F0.5-favoring auto-apply gate. Used as the
// robust correction backbone alongside the engine's curated fast-paths.
struct UnifiedDecoder {
    let trie: WordTrie
    let personalDictionary: PersonalDictionaryService

    let maxEditDistance = 2
    let prefixCandidateLimit = 12
    let suggestionLimit = 3

    init(trie: WordTrie = .shared, personalDictionary: PersonalDictionaryService = .shared) {
        self.trie = trie
        self.personalDictionary = personalDictionary
    }

    struct Candidate: Equatable {
        let word: String
        let score: Double
        let distance: Int
        let confidence: Double
    }

    // limit caps the returned list. Suggestion UI wants the few best (default),
    // but context disambiguation (#2) needs the full closest-distance neighborhood
    // so the right-by-context word is not dropped before the bigram can pick it.
    //
    // includePrefixCompletions adds words that merely extend the typed string
    // (good for in-progress suggestions). Auto-apply runs on a completed token,
    // where those completions are noise that injects spurious distance-0 entries,
    // so it asks for edit-distance corrections only.
    func candidates(for token: String, limit: Int? = nil, includePrefixCompletions: Bool = true) -> [Candidate] {
        let typed = token.lowercased()
        guard !typed.isEmpty else { return [] }

        var matches = trie.search(typed, maxDistance: maxEditDistance)
        if includePrefixCompletions {
            matches.append(contentsOf: trie.prefixCompletions(for: typed, limit: prefixCandidateLimit))
        }

        var best: [String: WordTrie.Match] = [:]
        for match in matches {
            if let existing = best[match.word], existing.distance <= match.distance { continue }
            best[match.word] = match
        }

        let ranked = best.values
            .map { scored($0) }
            .sorted { lhs, rhs in
                if lhs.distance == 0 && rhs.distance != 0 { return true }
                if rhs.distance == 0 && lhs.distance != 0 { return false }
                return lhs.score > rhs.score
            }
        return Array(ranked.prefix(limit ?? suggestionLimit))
    }
}

extension UnifiedDecoder {
    private var logMaxScore: Double { Foundation.log(10000) }
    private var editWeight: Double { 0.30 }
    private var distanceConfidence: [Int: Double] { [0: 0.99, 1: 0.86, 2: 0.62] }

    func scored(_ match: WordTrie.Match) -> Candidate {
        let lm = Foundation.log(max(match.score, 1)) / logMaxScore
        let editPenalty = Double(match.distance) * editWeight
        let rawScore = lm - editPenalty
        let base = distanceConfidence[match.distance] ?? max(0, 0.62 - Double(match.distance - 2) * 0.2)
        let freqBoost = (lm - 0.5) * 0.06
        let confidence = max(0, min(1, base + freqBoost))
        return Candidate(word: match.word, score: rawScore, distance: match.distance, confidence: confidence)
    }
}

extension UnifiedDecoder {
    private var autoApplyConfidence: Double { 0.80 }
    private var autoApplyMargin: Double { 0.10 }

    func isProtected(_ token: String) -> Bool {
        let lower = token.lowercased()
        return trie.contains(lower) || personalDictionary.containsLearnedWord(lower)
    }

    // apply is non-nil only for an unprotected token whose best correction is a
    // distance>0 word clearing the confidence gate and beating the runner-up by
    // the margin. suggestions is always the ranked candidate list.
    func evaluate(token: String) -> (apply: Candidate?, suggestions: [Candidate]) {
        let suggestions = candidates(for: token)
        guard !isProtected(token) else { return (nil, suggestions) }
        guard let top = suggestions.first, top.distance > 0,
              top.confidence >= autoApplyConfidence else {
            return (nil, suggestions)
        }
        if suggestions.count >= 2, suggestions[1].confidence >= top.confidence - autoApplyMargin {
            return (nil, suggestions)
        }
        return (top, suggestions)
    }
}
