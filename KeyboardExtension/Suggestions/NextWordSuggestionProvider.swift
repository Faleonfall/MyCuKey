import Foundation

// MARK: - Next Word Entry

struct NextWordEntry: Equatable {
    let context: String
    let candidate: String
    let score: Double
}

// MARK: - Next Word Lexicon

final class NextWordLexicon {
    static let shared = NextWordLexicon()

    private final class BundleToken {}

    private let resourceName = "EnglishNextWordLexicon"
    private let fallbackEntries: [NextWordEntry]
    private lazy var entriesByContext: [String: [NextWordEntry]] = Dictionary(
        grouping: loadEntries(),
        by: { $0.context.lowercased() }
    ).mapValues { entries in
        entries.sorted {
            if $0.score != $1.score {
                return $0.score > $1.score
            }
            return $0.candidate < $1.candidate
        }
    }

    init(fallbackEntries: [NextWordEntry]? = nil) {
        self.fallbackEntries = fallbackEntries ?? Self.defaultEntries
    }

    func entries(for context: String) -> [NextWordEntry] {
        entriesByContext[context.lowercased()] ?? []
    }

    // MARK: - Loading

    private func loadEntries() -> [NextWordEntry] {
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

    nonisolated private static func entry(from line: Substring) -> NextWordEntry? {
        let parts = line.split(separator: "\t")
        guard parts.count == 3,
              let score = Double(parts[2]) else {
            return nil
        }
        return NextWordEntry(
            context: String(parts[0]).lowercased(),
            candidate: String(parts[1]),
            score: score
        )
    }

    private static let defaultEntries: [NextWordEntry] = [
        NextWordEntry(context: "<s>", candidate: "I", score: 10000),
        NextWordEntry(context: "<s>", candidate: "The", score: 9800),
        NextWordEntry(context: "<s>", candidate: "You", score: 9600),
        NextWordEntry(context: "i", candidate: "think", score: 10000),
        NextWordEntry(context: "i", candidate: "have", score: 9800),
        NextWordEntry(context: "i", candidate: "am", score: 9600),
        NextWordEntry(context: "how are", candidate: "you", score: 10000),
        NextWordEntry(context: "<any>", candidate: "the", score: 7200),
        NextWordEntry(context: "<any>", candidate: "I", score: 7000),
        NextWordEntry(context: "<any>", candidate: "you", score: 6800)
    ]
}

// MARK: - Next Word Suggestion Provider

struct NextWordSuggestionProvider {
    static let shared = NextWordSuggestionProvider()

    private let lexicon: NextWordLexicon

    init(lexicon: NextWordLexicon = .shared) {
        self.lexicon = lexicon
    }

    func suggestions(for context: SuggestionContext, limit: Int = 3) -> [SuggestionBarCell] {
        guard context.mode == .nextWord else { return [] }

        let keyedEntries = rankedEntries(for: context)
        var seen = Set<String>()
        return keyedEntries
            .filter { entry in
                let key = entry.candidate.lowercased()
                return seen.insert(key).inserted
            }
            .prefix(limit)
            .map { entry in
                SuggestionBarCell(
                    text: displayText(for: entry.candidate, context: context),
                    source: .nextWordLexicon,
                    role: .prediction,
                    confidence: confidence(for: entry.score)
                )
            }
    }

    private func rankedEntries(for context: SuggestionContext) -> [NextWordEntry] {
        let keys = contextKeys(for: context)
        return keys.flatMap { key, boost in
            lexicon.entries(for: key).map { entry in
                NextWordEntry(
                    context: entry.context,
                    candidate: entry.candidate,
                    score: entry.score + boost
                )
            }
        }
        .sorted {
            if $0.score != $1.score {
                return $0.score > $1.score
            }
            return $0.candidate < $1.candidate
        }
    }

    private func contextKeys(for context: SuggestionContext) -> [(key: String, boost: Double)] {
        if context.isAtSentenceStart {
            return [("<s>", 4_000), ("<any>", 0)]
        }

        var keys: [(key: String, boost: Double)] = []
        if context.previousTokens.count >= 2 {
            keys.append((context.previousTokens.suffix(2).joined(separator: " "), 5_000))
        }
        if let last = context.previousTokens.last {
            keys.append((last, 3_000))
        }
        keys.append(("<any>", 0))
        return keys
    }

    private func displayText(for candidate: String, context: SuggestionContext) -> String {
        if candidate.lowercased() == "i" {
            return "I"
        }

        guard context.isAtSentenceStart else {
            return candidate
        }

        return candidate.prefix(1).uppercased() + candidate.dropFirst()
    }

    private func confidence(for score: Double) -> Double {
        max(0.50, min(0.97, 0.50 + score / 20_000))
    }
}
