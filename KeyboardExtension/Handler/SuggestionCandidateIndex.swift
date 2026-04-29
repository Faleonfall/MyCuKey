import Foundation

// MARK: - Suggestion Candidate Index

final class SuggestionCandidateIndex {
    static let shared = SuggestionCandidateIndex()

    private let lexicon: WordFrequencyLexicon
    private lazy var entriesByLength: [Int: [WordFrequencyEntry]] = Dictionary(grouping: lexicon.entries, by: { $0.word.count })
    private lazy var prefixBuckets: [String: [WordFrequencyEntry]] = buildPrefixBuckets()
    private var editCandidateCache: [String: [WordFrequencyEntry]] = [:]
    private var cacheOrder: [String] = []
    private let maxCacheEntries = 160

    init(lexicon: WordFrequencyLexicon = .shared) {
        self.lexicon = lexicon
    }

    // MARK: - Lookup

    func prefixCandidates(for prefix: String, limit: Int) -> [WordFrequencyEntry] {
        guard !prefix.isEmpty else { return [] }
        return Array((prefixBuckets[prefix.lowercased()] ?? []).prefix(limit))
    }

    func editCandidates(for input: String, maximumDistance: Int) -> [WordFrequencyEntry] {
        let key = "\(input)|\(maximumDistance)"
        if let cached = editCandidateCache[key] {
            return cached
        }

        let inputLength = input.count
        let candidateLengths = max(2, inputLength - maximumDistance)...(inputLength + maximumDistance)
        // This runs while typing, so each length bucket is capped before ranking.
        let perLengthLimit = inputLength <= 4 ? 1_200 : 850
        let candidates = candidateLengths.flatMap { length in
            Array((entriesByLength[length] ?? []).prefix(perLengthLimit))
        }
        store(candidates, for: key)
        return candidates
    }

    func score(for word: String) -> Double? {
        lexicon.score(for: word)
    }

    // MARK: - Index Construction

    private func buildPrefixBuckets() -> [String: [WordFrequencyEntry]] {
        var buckets: [String: [WordFrequencyEntry]] = [:]
        for entry in lexicon.entries where entry.word.count >= 2 {
            for length in 1...min(4, entry.word.count) {
                let prefix = String(entry.word.prefix(length))
                buckets[prefix, default: []].append(entry)
            }
        }

        for key in buckets.keys {
            buckets[key]?.sort { lhs, rhs in
                if lhs.score != rhs.score {
                    return lhs.score > rhs.score
                }
                return lhs.word < rhs.word
            }
        }

        return buckets
    }

    private func store(_ candidates: [WordFrequencyEntry], for key: String) {
        editCandidateCache[key] = candidates
        cacheOrder.append(key)

        while cacheOrder.count > maxCacheEntries {
            let oldest = cacheOrder.removeFirst()
            editCandidateCache.removeValue(forKey: oldest)
        }
    }
}
