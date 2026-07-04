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

        // High-frequency function words — these appear before most tokens, so
        // rows here fire far more often than any content-word row.
        "a": [
            "lot": 90, "few": 80, "little": 78, "good": 76, "great": 72, "new": 74,
            "bit": 70, "long": 64, "big": 66, "very": 56, "couple": 62, "day": 58,
        ],
        "and": [
            "the": 90, "i": 88, "then": 76, "it": 74, "a": 72, "we": 70, "you": 68,
            "that": 66, "he": 60, "she": 58, "they": 62, "now": 56,
        ],
        "that": [
            "is": 90, "was": 86, "the": 78, "it": 74, "i": 76, "you": 70, "we": 66,
            "would": 60, "will": 62, "they": 58, "he": 56,
        ],
        "this": [
            "is": 100, "was": 80, "one": 66, "time": 64, "year": 62, "week": 60,
            "morning": 58, "will": 56, "would": 54,
        ],
        "is": [
            "the": 90, "a": 86, "not": 82, "that": 70, "it": 68, "going": 72, "very": 64,
            "just": 62, "so": 60, "what": 58, "really": 56,
        ],
        "was": [
            "the": 88, "a": 86, "not": 80, "just": 66, "going": 70, "so": 64, "very": 62,
            "really": 58, "there": 56, "it": 60,
        ],
        "have": [
            "a": 90, "to": 100, "been": 88, "the": 74, "no": 66, "some": 62, "any": 60,
            "not": 58, "done": 56, "time": 54,
        ],
        "has": ["been": 100, "a": 80, "to": 78, "the": 70, "no": 60, "not": 58, "made": 54],
        "had": [
            "a": 90, "to": 100, "been": 84, "the": 74, "no": 66, "some": 60, "not": 58,
            "never": 56,
        ],
        "will": ["be": 100, "not": 78, "have": 72, "get": 64, "take": 60, "make": 58, "do": 56],
        "would": ["be": 100, "have": 84, "not": 74, "like": 78, "love": 60, "make": 56],
        "can": ["be": 90, "do": 80, "get": 74, "see": 70, "make": 66, "help": 64, "take": 58],
        "could": ["be": 100, "have": 80, "not": 72, "do": 64, "see": 60, "get": 58],
        "on": [
            "the": 100, "a": 76, "my": 70, "this": 66, "that": 62, "it": 60, "your": 58,
            "top": 56, "his": 54,
        ],
        "at": [
            "the": 100, "least": 76, "a": 70, "all": 68, "this": 62, "my": 60, "home": 64,
            "work": 62, "night": 58,
        ],
        "from": ["the": 100, "a": 74, "my": 68, "his": 58, "her": 56, "this": 60, "you": 54],
        "about": ["the": 90, "it": 84, "a": 74, "this": 70, "that": 72, "my": 62, "you": 60],
        "be": [
            "a": 88, "the": 80, "able": 74, "there": 66, "done": 62, "good": 58, "more": 56,
            "very": 54,
        ],
        "been": ["a": 80, "the": 70, "there": 62, "so": 58, "very": 56, "doing": 54],
        "but": ["i": 90, "the": 76, "it": 80, "not": 66, "we": 64, "he": 58, "you": 62],
        "so": ["i": 84, "much": 90, "many": 76, "far": 68, "the": 60, "that": 62, "we": 58],
        "not": [
            "the": 70, "a": 66, "sure": 74, "going": 68, "be": 60, "really": 62, "very": 56,
            "that": 58,
        ],
        "just": [
            "a": 80, "the": 70, "want": 62, "like": 68, "got": 60, "need": 58, "one": 56,
            "as": 54,
        ],
        "very": ["good": 80, "much": 84, "well": 70, "nice": 62, "happy": 58, "long": 56],
        "there": ["is": 100, "are": 90, "was": 84, "were": 70, "will": 62, "would": 56],
        "what": ["is": 90, "the": 80, "a": 70, "you": 74, "i": 72, "we": 62, "do": 60],
        "when": ["the": 80, "i": 88, "you": 82, "we": 74, "it": 70, "he": 58, "they": 60],
        "going": ["to": 100, "on": 60, "back": 54, "out": 52, "through": 50],
        "want": ["to": 100, "a": 60, "the": 54, "it": 52, "you": 50, "more": 48],
        "need": ["to": 100, "a": 62, "the": 56, "some": 52, "more": 54, "it": 50, "help": 48],
        "like": ["the": 76, "a": 80, "to": 84, "this": 70, "that": 72, "it": 66, "you": 60],
        "one": ["of": 100, "day": 62, "more": 58, "thing": 60, "who": 52, "is": 54],
        "out": ["of": 100, "the": 70, "there": 62, "to": 58, "a": 52, "and": 50],
        "all": ["the": 100, "of": 84, "my": 60, "day": 58, "that": 62, "over": 52, "in": 54],
        "as": ["a": 84, "the": 80, "well": 76, "much": 60, "long": 58, "soon": 62, "it": 54],
        "our": ["own": 70, "house": 58, "time": 60, "team": 56, "way": 54, "family": 62],
        "his": ["own": 70, "life": 64, "way": 60, "name": 58, "head": 54, "wife": 52],
        "her": ["own": 70, "life": 64, "way": 58, "name": 56, "head": 52, "mom": 50],
    ]
}
