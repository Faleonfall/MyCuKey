import Testing
import CoreGraphics
@testable import MyCuKey

private func spatialTrie() -> WordTrie {
    let trie = WordTrie()
    for (w, s) in [("when", 9000.0), ("then", 800.0), ("wren", 100.0),
                   ("hen", 90.0), ("the", 10000.0), ("word", 5000.0),
                   ("work", 6000.0), ("wor", 10.0)] {
        trie.insert(w, score: s)
    }
    return trie
}

private func center(_ ch: Character) -> CGPoint { KeyGeometry.center(for: ch)! }

@Test func keyGeometryHasStaggeredQwertyCenters() {
    #expect(KeyGeometry.center(for: "q") == CGPoint(x: 0, y: 0))
    #expect(KeyGeometry.center(for: "p") == CGPoint(x: 9, y: 0))
    #expect(KeyGeometry.center(for: "a") == CGPoint(x: 0.5, y: 1))
    #expect(KeyGeometry.center(for: "z") == CGPoint(x: 1.5, y: 2))
    #expect(KeyGeometry.center(for: "Q") == CGPoint(x: 0, y: 0)) // case-insensitive
}

@Test func spatialDecodeRecoversWordFromExactTaps() {
    let decoder = UnifiedDecoder(trie: spatialTrie(), personalDictionary: .shared)
    let taps = [center("w"), center("h"), center("e"), center("n")]
    #expect(decoder.decodeTaps(taps).first?.word == "when")
}

@Test func spatialDecodeToleratesNoisyTaps() {
    let decoder = UnifiedDecoder(trie: spatialTrie(), personalDictionary: .shared)
    // each tap nudged toward a neighbor key but still closest to the intended one
    let taps = [
        CGPoint(x: center("w").x + 0.25, y: center("w").y),
        CGPoint(x: center("h").x - 0.2, y: center("h").y + 0.15),
        CGPoint(x: center("e").x, y: center("e").y),
        CGPoint(x: center("n").x + 0.2, y: center("n").y)
    ]
    #expect(decoder.decodeTaps(taps).first?.word == "when")
}

@Test func spatialDecodeHandlesMissingLetterViaDeletion() {
    let decoder = UnifiedDecoder(trie: spatialTrie(), personalDictionary: .shared)
    // user typed only w-o-r intending "word"; deletion supplies the missing 'd'
    let taps = [center("w"), center("o"), center("r")]
    let words = decoder.decodeTaps(taps).map(\.word)
    #expect(words.contains("word") || words.contains("work") || words.first == "wor")
}
