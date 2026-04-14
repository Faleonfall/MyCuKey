import Foundation

struct LearnedWordEntry: Codable, Equatable, Identifiable {
    let normalizedWord: String
    let createdAt: Date

    var id: String { normalizedWord }
}

enum PersonalDictionaryConfiguration {
    static let appGroupSuiteName = "group.com.kvolodymyr.MyCuKey"
    static let learnedWordsKey = "personal_dictionary.learned_words"
    static let revertCountsKey = "personal_dictionary.revert_counts"
    static let promotionThreshold = 2
    static let maxWordLength = 40
}

final class PersonalDictionaryService {
    static let shared = PersonalDictionaryService()

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private var learnedWordsCache: [LearnedWordEntry] = []
    private var learnedWordSetCache: Set<String> = []

    init(defaults: UserDefaults? = nil) {
        if let defaults {
            self.defaults = defaults
        } else if let sharedDefaults = UserDefaults(suiteName: PersonalDictionaryConfiguration.appGroupSuiteName) {
            self.defaults = sharedDefaults
        } else {
            self.defaults = .standard
        }
        reloadLearnedWordsCache()
    }

    func containsLearnedWord(_ word: String) -> Bool {
        reloadLearnedWordsCache()
        guard let normalized = Self.normalizeLearnableWord(word) else { return false }
        return learnedWordSetCache.contains(normalized)
    }

    func allWords() -> [LearnedWordEntry] {
        reloadLearnedWordsCache()
        return learnedWordsCache
            .sorted { lhs, rhs in
                if lhs.normalizedWord == rhs.normalizedWord {
                    return lhs.createdAt < rhs.createdAt
                }
                return lhs.normalizedWord < rhs.normalizedWord
            }
    }

    @discardableResult
    func addWord(_ word: String) -> LearnedWordEntry? {
        reloadLearnedWordsCache()
        guard let normalized = Self.normalizeLearnableWord(word) else { return nil }

        if learnedWordSetCache.contains(normalized),
           let existing = learnedWordsCache.first(where: { $0.normalizedWord == normalized }) {
            clearRevertCount(forNormalizedWord: normalized)
            return existing
        }

        var words = learnedWordsCache
        let entry = LearnedWordEntry(normalizedWord: normalized, createdAt: Date())
        words.append(entry)
        saveLearnedWords(words)
        clearRevertCount(forNormalizedWord: normalized)
        return entry
    }

    func removeWord(_ word: String) {
        reloadLearnedWordsCache()
        guard let normalized = Self.normalizeLearnableWord(word) else { return }
        let filtered = learnedWordsCache.filter { $0.normalizedWord != normalized }
        saveLearnedWords(filtered)
        clearRevertCount(forNormalizedWord: normalized)
    }

    func clearAll() {
        defaults.removeObject(forKey: PersonalDictionaryConfiguration.learnedWordsKey)
        defaults.removeObject(forKey: PersonalDictionaryConfiguration.revertCountsKey)
        learnedWordsCache = []
        learnedWordSetCache = []
    }

    func recordRevertedCorrection(originalWord: String) {
        reloadLearnedWordsCache()
        guard let normalized = Self.normalizeLearnableWord(originalWord) else { return }
        guard !learnedWordSetCache.contains(normalized) else { return }

        var counts = loadRevertCounts()
        let nextCount = (counts[normalized] ?? 0) + 1
        counts[normalized] = nextCount

        if nextCount >= PersonalDictionaryConfiguration.promotionThreshold {
            _ = addWord(normalized)
            counts.removeValue(forKey: normalized)
        }

        saveRevertCounts(counts)
    }

    func revertCount(for word: String) -> Int {
        guard let normalized = Self.normalizeLearnableWord(word) else { return 0 }
        return loadRevertCounts()[normalized] ?? 0
    }

    static func normalizeLearnableWord(_ word: String) -> String? {
        let trimmed = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard trimmed.count >= 2, trimmed.count <= PersonalDictionaryConfiguration.maxWordLength else { return nil }
        guard !trimmed.contains(where: \.isWhitespace) else { return nil }

        var containsLetter = false
        for scalar in trimmed.unicodeScalars {
            if CharacterSet.letters.contains(scalar) {
                containsLetter = true
                continue
            }
            if CharacterSet.decimalDigits.contains(scalar) {
                continue
            }
            if scalar == "'" || scalar == "-" {
                continue
            }
            return nil
        }

        guard containsLetter else { return nil }
        return trimmed.lowercased()
    }

    private func loadLearnedWordsFromStorage() -> [LearnedWordEntry] {
        guard let data = defaults.data(forKey: PersonalDictionaryConfiguration.learnedWordsKey),
              let words = try? decoder.decode([LearnedWordEntry].self, from: data) else {
            return []
        }
        return words
    }

    private func saveLearnedWords(_ words: [LearnedWordEntry]) {
        learnedWordsCache = words
        learnedWordSetCache = Set(words.map(\.normalizedWord))
        guard let data = try? encoder.encode(words) else { return }
        defaults.set(data, forKey: PersonalDictionaryConfiguration.learnedWordsKey)
    }

    private func reloadLearnedWordsCache() {
        learnedWordsCache = loadLearnedWordsFromStorage()
        learnedWordSetCache = Set(learnedWordsCache.map(\.normalizedWord))
    }

    private func loadRevertCounts() -> [String: Int] {
        defaults.dictionary(forKey: PersonalDictionaryConfiguration.revertCountsKey) as? [String: Int] ?? [:]
    }

    private func saveRevertCounts(_ counts: [String: Int]) {
        defaults.set(counts, forKey: PersonalDictionaryConfiguration.revertCountsKey)
    }

    private func clearRevertCount(forNormalizedWord word: String) {
        var counts = loadRevertCounts()
        counts.removeValue(forKey: word)
        saveRevertCounts(counts)
    }
}
