import Foundation

// MARK: - Word Frequency Entry

struct WordFrequencyEntry: Equatable {
    let word: String
    let score: Double
}

// MARK: - Word Frequency Lexicon

final class WordFrequencyLexicon {
    static let shared = WordFrequencyLexicon()

    private final class BundleToken {}

    private let resourceName = "EnglishSuggestionLexicon"
    private let fallbackEntries: [WordFrequencyEntry]
    private lazy var loadedEntries: [WordFrequencyEntry] = loadEntries()
    private lazy var scoreByWord: [String: Double] = {
        var scores: [String: Double] = [:]
        for entry in loadedEntries {
            scores[entry.word] = max(scores[entry.word] ?? 0, entry.score)
        }
        return scores
    }()

    init(fallbackEntries: [WordFrequencyEntry]? = nil) {
        self.fallbackEntries = fallbackEntries ?? CommonWordLexicon.words.map {
            WordFrequencyEntry(word: $0, score: 7_000)
        }
    }

    var entries: [WordFrequencyEntry] {
        loadedEntries
    }

    func score(for word: String) -> Double? {
        scoreByWord[word.lowercased()]
    }

    func contains(_ word: String) -> Bool {
        score(for: word) != nil
    }

    // MARK: - Loading

    private func loadEntries() -> [WordFrequencyEntry] {
        guard let url = lexiconURL() else {
            return fallbackEntries
        }

        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
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

    nonisolated private static func entry(from line: Substring) -> WordFrequencyEntry? {
        let parts = line.split(separator: "\t")
        guard parts.count == 2,
              let score = Double(parts[1]) else {
            return nil
        }
        return WordFrequencyEntry(word: String(parts[0]), score: score)
    }
}
