import Foundation

// MARK: - Suggestion Candidate Index

// Backed by a WordTrie so prefix completion and bounded edit-distance lookup
// have uniform, complete coverage at every token length. This replaces the old
// length-bucket scan that capped each bucket and silently dropped the right
// neighbor for longer tokens (the "5 chars returns nothing" suggestion cliff).
final class SuggestionCandidateIndex {
    static let shared = SuggestionCandidateIndex()

    private let lexicon: WordFrequencyLexicon
    private let trie: WordTrie
    private var editCandidateCache: [String: [WordFrequencyEntry]] = [:]
    private var cacheOrder: [String] = []
    private let maxCacheEntries = 160
    // Bound result size: candidates are re-scored downstream, so keep the
    // highest-frequency matches and drop the long tail.
    private let maxEditCandidates = 600

    init(lexicon: WordFrequencyLexicon = .shared, trie: WordTrie = .shared) {
        self.lexicon = lexicon
        self.trie = trie
    }

    // MARK: - Lookup

    func prefixCandidates(for prefix: String, limit: Int) -> [WordFrequencyEntry] {
        guard !prefix.isEmpty else { return [] }
        return trie.prefixCompletions(for: prefix.lowercased(), limit: limit)
            .map { WordFrequencyEntry(word: $0.word, score: $0.score) }
    }

    func editCandidates(for input: String, maximumDistance: Int) -> [WordFrequencyEntry] {
        let key = "\(input)|\(maximumDistance)"
        if let cached = editCandidateCache[key] {
            return cached
        }

        // Closest matches first, then most frequent. Guarantees a distance-1
        // correction is never dropped in favor of a distant but high-frequency
        // (or obscure low-frequency) word when the result set is capped.
        let candidates = trie.search(input.lowercased(), maxDistance: maximumDistance)
            .sorted { ($0.distance, -$0.score) < ($1.distance, -$1.score) }
            .prefix(maxEditCandidates)
            .map { WordFrequencyEntry(word: $0.word, score: $0.score) }

        store(Array(candidates), for: key)
        return Array(candidates)
    }

    func score(for word: String) -> Double? {
        lexicon.score(for: word)
    }

    // MARK: - Cache

    private func store(_ candidates: [WordFrequencyEntry], for key: String) {
        editCandidateCache[key] = candidates
        cacheOrder.append(key)

        while cacheOrder.count > maxCacheEntries {
            let oldest = cacheOrder.removeFirst()
            editCandidateCache.removeValue(forKey: oldest)
        }
    }
}
