import Testing

@testable import MyCuKey

private func makeDecoder() -> UnifiedDecoder {
    let trie = WordTrie()
    for (w, s) in [
        ("the", 10000.0), ("they", 600.0), ("then", 500.0),
        ("there", 800.0), ("cat", 900.0),
    ] {
        trie.insert(w, score: s)
    }
    return UnifiedDecoder(trie: trie, personalDictionary: .shared)
}

@Test func decoderGeneratesAndDedupesCandidates() {
    let decoder = makeDecoder()
    let words = Set(decoder.candidates(for: "teh").map(\.word))
    #expect(words.contains("the"))
    let exact = decoder.candidates(for: "the")
    #expect(exact.first?.word == "the")
    #expect(exact.filter { $0.word == "the" }.count == 1)
}

@Test func decoderScoresExactHighestAndDistanceOneStrong() {
    let decoder = makeDecoder()
    let exact = decoder.candidates(for: "the")
    #expect(exact.first?.word == "the")
    #expect((exact.first?.confidence ?? 0) >= 0.95)

    let repair = decoder.candidates(for: "teh").first { $0.word == "the" }
    #expect(repair != nil)
    #expect(repair!.distance == 1)
    #expect(repair!.confidence >= 0.80 && repair!.confidence < 0.95)
}

@Test func decoderProtectsValidWordsAndGatesAutoApply() {
    let decoder = makeDecoder()

    let valid = decoder.evaluate(token: "the")
    #expect(valid.apply == nil)
    #expect(valid.suggestions.first?.word == "the")

    let typo = decoder.evaluate(token: "teh")
    #expect(typo.apply?.word == "the")

    let junk = decoder.evaluate(token: "qzx")
    #expect(junk.apply == nil)
}
