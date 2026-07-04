import Foundation

// MARK: - Key Adjacency
// Static QWERTY neighbor map used to weight the noisy-channel edit costs: a
// substitution between physically adjacent keys is far more likely to be a fat
// finger than one across the keyboard, so it should cost less. This is the
// static stand-in for a live touch model — no coordinates needed, works in
// pure text tests, and matches how people actually miss keys.
enum KeyAdjacency {
    static let neighbors: [Character: Set<Character>] = [
        "q": ["w", "a"],
        "w": ["q", "e", "a", "s"],
        "e": ["w", "r", "s", "d"],
        "r": ["e", "t", "d", "f"],
        "t": ["r", "y", "f", "g"],
        "y": ["t", "u", "g", "h"],
        "u": ["y", "i", "h", "j"],
        "i": ["u", "o", "j", "k"],
        "o": ["i", "p", "k", "l"],
        "p": ["o", "l"],
        "a": ["q", "w", "s", "z"],
        "s": ["a", "d", "w", "e", "z", "x"],
        "d": ["s", "f", "e", "r", "x", "c"],
        "f": ["d", "g", "r", "t", "c", "v"],
        "g": ["f", "h", "t", "y", "v", "b"],
        "h": ["g", "j", "y", "u", "b", "n"],
        "j": ["h", "k", "u", "i", "n", "m"],
        "k": ["j", "l", "i", "o", "m"],
        "l": ["k", "p", "o"],
        "z": ["a", "s", "x"],
        "x": ["z", "c", "s", "d"],
        "c": ["x", "v", "d", "f"],
        "v": ["c", "b", "f", "g"],
        "b": ["v", "n", "g", "h"],
        "n": ["b", "m", "h", "j"],
        "m": ["n", "j", "k"],
    ]

    static func areAdjacent(_ a: Character, _ b: Character) -> Bool {
        neighbors[a]?.contains(b) ?? false
    }
}

// MARK: - Edit Costs
// Weighted costs for the trie search. Tuned so a single adjacent-key slip is
// clearly cheaper than a random substitution, and so common mechanical errors
// (transposed pair, doubled key) sit between the two.
enum EditCost {
    // Substituting the intended key with one of its physical neighbors.
    static let adjacentSubstitution = 0.5
    // Substituting with a non-adjacent key — a genuine misspelling signal.
    static let substitution = 1.0
    // Two adjacent characters swapped — classic fast-typing error.
    static let transposition = 0.6
    // An extra character that duplicates its predecessor — bounced key.
    static let duplicateInsertion = 0.5
    // Any other extra character in the typed token.
    static let insertion = 0.9
    // A character the typed token is missing.
    static let deletion = 0.9

    static func substitutionCost(_ typed: Character, _ intended: Character) -> Double {
        if typed == intended { return 0 }
        return KeyAdjacency.areAdjacent(typed, intended) ? adjacentSubstitution : substitution
    }
}
