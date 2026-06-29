import Foundation

final class WordTrie {
    final class Node {
        var children: [Character: Node] = [:]
        var word: String?
        var score: Double = 0
    }

    let root = Node()

    func insert(_ word: String, score: Double) {
        var node = root
        for ch in word {
            if let next = node.children[ch] {
                node = next
            } else {
                let next = Node()
                node.children[ch] = next
                node = next
            }
        }
        node.word = word
        node.score = score
    }

    func contains(_ word: String) -> Bool {
        node(for: word)?.word != nil
    }

    func score(for word: String) -> Double? {
        guard let node = node(for: word), node.word != nil else { return nil }
        return node.score
    }

    private func node(for word: String) -> Node? {
        var node = root
        for ch in word {
            guard let next = node.children[ch] else { return nil }
            node = next
        }
        return node
    }
}

extension WordTrie {
    struct Match: Equatable {
        let word: String
        let score: Double
        let distance: Int
    }
}

// MARK: - Prefix Completion
extension WordTrie {
    // All stored words extending `prefix`, ranked by score, capped at `limit`.
    func prefixCompletions(for prefix: String, limit: Int) -> [Match] {
        guard !prefix.isEmpty, limit > 0 else { return [] }
        var node = root
        for ch in prefix {
            guard let next = node.children[ch] else { return [] }
            node = next
        }
        var matches: [Match] = []
        collect(from: node, into: &matches)
        return Array(matches.sorted { $0.score > $1.score }.prefix(limit))
    }

    private func collect(from node: Node, into matches: inout [Match]) {
        if let word = node.word {
            matches.append(Match(word: word, score: node.score, distance: 0))
        }
        for child in node.children.values {
            collect(from: child, into: &matches)
        }
    }
}

// MARK: - Bounded Damerau-Levenshtein Search
extension WordTrie {
    // All stored words within optimal-string-alignment (adjacent transposition)
    // edit distance <= maxDistance of `word`, each Match carrying its true distance.
    func search(_ word: String, maxDistance: Int) -> [Match] {
        let chars = Array(word)
        let firstRow = Array(0...chars.count)
        var results: [Match] = []
        for (childChar, child) in root.children {
            searchRecursive(
                node: child, nodeChar: childChar, prevNodeChar: nil,
                chars: chars, previousRow: firstRow, prevPreviousRow: nil,
                maxDistance: maxDistance, results: &results)
        }
        return results
    }

    private func searchRecursive(
        node: Node, nodeChar: Character, prevNodeChar: Character?,
        chars: [Character], previousRow: [Int],
        prevPreviousRow: [Int]?, maxDistance: Int,
        results: inout [Match]
    ) {
        let cols = chars.count + 1
        var currentRow = [previousRow[0] + 1]
        currentRow.reserveCapacity(cols)
        for col in 1..<cols {
            let insertCost = currentRow[col - 1] + 1
            let deleteCost = previousRow[col] + 1
            let substituteCost = previousRow[col - 1] + (chars[col - 1] == nodeChar ? 0 : 1)
            var cost = min(insertCost, deleteCost, substituteCost)
            if col > 1, let pp = prevPreviousRow, let prevChar = prevNodeChar,
                chars[col - 1] == prevChar, chars[col - 2] == nodeChar
            {
                cost = min(cost, pp[col - 2] + 1)
            }
            currentRow.append(cost)
        }
        if let last = currentRow.last, last <= maxDistance, let stored = node.word {
            results.append(Match(word: stored, score: node.score, distance: last))
        }
        if let smallest = currentRow.min(), smallest <= maxDistance {
            for (childChar, child) in node.children {
                searchRecursive(
                    node: child, nodeChar: childChar, prevNodeChar: nodeChar,
                    chars: chars, previousRow: currentRow,
                    prevPreviousRow: previousRow, maxDistance: maxDistance,
                    results: &results)
            }
        }
    }
}

// MARK: - Shared Build From Lexicon
extension WordTrie {
    static let shared: WordTrie = build(from: WordFrequencyLexicon.shared.entries)

    static func build(from entries: [WordFrequencyEntry]) -> WordTrie {
        let trie = WordTrie()
        for entry in entries {
            let word = entry.word.lowercased()
            guard !word.isEmpty else { continue }
            trie.insert(word, score: entry.score)
        }
        return trie
    }
}
