import Foundation

// MARK: - Bigram Context Model
// Roadmap #2: a lightweight context model giving the strength that one word
// follows another, P(next | prev). Used to break ties when a fat-finger
// correction is ambiguous at edit distance (e.g. "slent" -> spent vs silent):
// the previous word decides ("i spent" >> "i silent").
//
// v1 ships an in-code curated seed of high-frequency English collocations. The
// table is the only thing that limits coverage; it can be replaced with a
// corpus-derived table later without changing any call site. Association is
// normalized per row so the best-known follower scores 1.0 and an unseen pair
// scores 0.
final class BigramModel {
    static let shared = BigramModel()

    // prev (lowercased) -> [next (lowercased): weight]
    private let table: [String: [String: Double]]
    private let rowMax: [String: Double]

    init(table: [String: [String: Double]]? = nil) {
        let resolved = table ?? Self.seed
        self.table = resolved
        self.rowMax = resolved.mapValues { $0.values.max() ?? 0 }
    }

    // Strength that `next` follows `prev`, in [0, 1]. 0 means the pair is unseen
    // (or there is no previous word), so callers can treat 0 as "no signal".
    func association(prev: String?, next: String) -> Double {
        guard let prevRaw = prev?.lowercased(), !prevRaw.isEmpty,
            let row = table[prevRaw], let weight = row[next.lowercased()],
            let maxWeight = rowMax[prevRaw], maxWeight > 0
        else {
            return 0
        }
        return weight / maxWeight
    }
}

// MARK: - Seed Data
extension BigramModel {
    // Curated common collocations. Weights are relative within each row only.
    // Grouped by the kind of disambiguation they enable.
    static let seed: [String: [String: Double]] = [
        // Pronoun + verb (subject openers)
        "i": [
            "spent": 90, "am": 100, "have": 95, "will": 80, "think": 85, "need": 80,
            "want": 80, "was": 88, "can": 82, "would": 75, "know": 84, "see": 70,
            "feel": 68, "like": 72, "love": 66, "got": 74, "had": 78, "get": 70,
            "hope": 60, "really": 58, "just": 62, "did": 64, "do": 66,
        ],
        "you": [
            "are": 100, "can": 90, "have": 88, "will": 80, "should": 75, "know": 78,
            "want": 76, "need": 74, "were": 70, "did": 66, "do": 72, "get": 64,
        ],
        "we": [
            "are": 100, "have": 92, "will": 85, "can": 82, "should": 76, "need": 74,
            "were": 70, "did": 64, "do": 70, "got": 66,
        ],
        "they": ["are": 100, "have": 90, "will": 84, "can": 80, "were": 78, "did": 66, "do": 70],
        "he": ["is": 100, "was": 95, "has": 88, "will": 82, "had": 80, "can": 74, "did": 66],
        "she": ["is": 100, "was": 95, "has": 88, "will": 82, "had": 80, "can": 74, "did": 66],
        "it": ["is": 100, "was": 95, "will": 82, "has": 78, "can": 76, "had": 72],

        // Verb + object / continuation
        "spent": [
            "my": 90, "the": 85, "a": 80, "time": 88, "most": 70, "all": 72,
            "his": 60, "her": 58, "it": 64, "that": 62, "some": 66,
        ],
        "get": [
            "the": 90, "to": 88, "things": 80, "it": 85, "a": 82, "out": 78, "up": 76,
            "back": 74, "started": 70, "ready": 66, "rid": 60, "this": 68, "done": 72,
        ],
        "things": [
            "done": 90, "to": 80, "that": 78, "like": 72, "up": 64, "out": 66,
            "are": 82, "you": 60, "in": 58, "i": 56,
        ],
        "are": [
            "trying": 80, "you": 90, "the": 70, "going": 85, "not": 78, "very": 66,
            "still": 64, "a": 60, "all": 62, "we": 58,
        ],
        "trying": ["to": 100, "hard": 60, "not": 55, "my": 40],
        "doing": [
            "the": 80, "a": 78, "it": 82, "my": 70, "well": 66, "this": 68, "that": 64,
            "good": 60, "fine": 58, "most": 62,
        ],
        "to": [
            "the": 90, "be": 95, "do": 88, "get": 86, "go": 84, "make": 80, "see": 78,
            "have": 82, "a": 76, "my": 70, "you": 68,
        ],

        // Possessive + noun
        "my": [
            "time": 88, "own": 90, "life": 85, "friend": 80, "name": 82, "mind": 78,
            "way": 76, "head": 70, "hands": 66, "phone": 72, "house": 68, "car": 64,
            "job": 66, "family": 74, "mom": 60, "dad": 58, "people": 56,
        ],
        "your": [
            "time": 85, "own": 88, "life": 82, "name": 84, "friend": 78, "way": 74,
            "mind": 72, "phone": 76, "house": 66, "people": 60,
        ],

        // Preposition + article / object
        "of": [
            "the": 100, "a": 80, "my": 70, "his": 60, "her": 58, "it": 64, "course": 72,
            "them": 62, "us": 60, "you": 58, "people": 56,
        ],
        "in": [
            "the": 100, "a": 82, "my": 72, "this": 70, "that": 66, "his": 60, "her": 58,
            "it": 64, "fact": 68, "order": 66, "front": 62, "world": 74, "time": 60,
        ],
        "the": [
            "world": 80, "time": 78, "people": 82, "things": 70, "way": 76, "most": 66,
            "same": 68, "first": 72, "last": 64, "best": 70, "other": 66, "thing": 74,
        ],
        "for": [
            "me": 90, "you": 88, "the": 80, "a": 78, "this": 70, "that": 68, "us": 72,
            "him": 64, "her": 62, "my": 66, "your": 60, "them": 64,
        ],
        "with": [
            "the": 90, "a": 80, "my": 74, "you": 78, "his": 62, "her": 60, "it": 66,
            "them": 64, "me": 70,
        ],

        // Number words
        "fifty": [
            "five": 90, "six": 60, "seven": 55, "percent": 50, "thousand": 45, "dollars": 40,
        ],
        "twenty": ["five": 80, "four": 60, "three": 55, "percent": 50, "years": 45],
        "thirty": ["five": 80, "four": 58, "percent": 50, "years": 45],

        // Sentence-start backoff handled by caller; common nouns + verb
        "people": [
            "are": 90, "who": 80, "in": 70, "of": 66, "that": 72, "have": 74,
            "will": 60, "were": 64, "like": 62, "do": 58, "and": 56,
        ],
        "time": ["to": 85, "for": 80, "is": 78, "of": 70, "and": 66, "the": 60, "we": 58, "i": 56],
    ]
}
