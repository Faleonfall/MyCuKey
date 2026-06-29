import Testing

@testable import MyCuKey

@Test func trieInsertAndContains() {
    let trie = WordTrie()
    trie.insert("the", score: 10000)
    trie.insert("then", score: 500)
    #expect(trie.contains("the"))
    #expect(trie.contains("then"))
    #expect(!trie.contains("th"))  // prefix is not a stored word
    #expect(!trie.contains("them"))
    #expect(trie.score(for: "the") == 10000)
    #expect(trie.score(for: "th") == nil)
}

@Test func triePrefixCompletionRanksByScore() {
    let trie = WordTrie()
    trie.insert("the", score: 10000)
    trie.insert("then", score: 500)
    trie.insert("there", score: 800)
    trie.insert("cat", score: 900)
    let completions = trie.prefixCompletions(for: "the", limit: 2)
    #expect(completions.map(\.word) == ["the", "there"])
    #expect(completions.allSatisfy { $0.distance == 0 })
    #expect(trie.prefixCompletions(for: "xyz", limit: 5).isEmpty)
    #expect(trie.prefixCompletions(for: "", limit: 5).isEmpty)
}

@Test func trieBoundedDamerauSearch() {
    let trie = WordTrie()
    for (w, s) in [("the", 10000.0), ("then", 500.0), ("they", 600.0), ("cat", 900.0)] {
        trie.insert(w, score: s)
    }
    #expect(
        trie.search("the", maxDistance: 2).contains(
            WordTrie.Match(word: "the", score: 10000, distance: 0)))
    let teh = trie.search("teh", maxDistance: 2).first { $0.word == "the" }
    #expect(teh?.distance == 1)  // transposition is one Damerau edit
    let words = Set(trie.search("thu", maxDistance: 2).map(\.word))
    #expect(words.contains("the"))
    #expect(!words.contains("cat"))
}

@Test func trieBuildsFromLexiconEntries() {
    let trie = WordTrie.build(from: WordFrequencyLexicon.shared.entries)
    #expect(trie.contains("the"))
    #expect(trie.contains("keyboard"))
    #expect(WordTrie.shared.contains("the"))
}
