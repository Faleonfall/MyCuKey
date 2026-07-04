import Testing
import UIKit

@testable import MyCuKey

// Roadmap #1: decoder-driven silent auto-apply. The trie noisy-channel decoder
// may commit a fix only when the winning repair is unambiguous (alone in its
// adjacency-weighted cost cluster) and the typed token is not a real or
// intentional word. These tests lock both the wins and the trust guards.
@MainActor
struct DecoderAutoApplyTests {
    @Test func commitsUnambiguousFatFingerCorrections() {
        // Each repair is alone in the winning cost cluster: peoole -> people is
        // a bounced double key; fivd -> five is d->e (adjacent) while find
        // needs v->n (not adjacent); movje -> movie is j->i (adjacent) with no
        // competing single-slip neighbor.
        let engine = AutocorrectionEngine()
        #expect(engine.evaluate(context: "peoole")?.corrected == "people")
        #expect(engine.evaluate(context: "fivd")?.corrected == "five")
        #expect(engine.evaluate(context: "movje")?.corrected == "movie")
    }

    @Test func leavesRealWordsMissingFromLexiconAlone() {
        // "wifi" is valid per UITextChecker even though it is absent from the
        // frequency lexicon, so it must never be silently rewritten.
        let engine = AutocorrectionEngine()
        #expect(engine.evaluate(context: "wifi") == nil)
    }

    @Test func leavesStrayDoubledLetterWordsAlone() {
        let engine = AutocorrectionEngine()
        #expect(engine.evaluate(context: "yourr") == nil)
        #expect(engine.evaluate(context: "herr") == nil)
    }

    @Test func leavesAmbiguousDenseNeighborTokensAloneWithoutContext() {
        // Each token keeps several mechanically plausible repairs in the
        // winning cost cluster (hoke: home/hole; worls: world/works; kint:
        // king/mint/lint), and "woh" is below the unigram length floor. With
        // no previous word the decoder defers on all of them.
        let engine = AutocorrectionEngine()
        #expect(engine.evaluate(context: "hoke") == nil)
        #expect(engine.evaluate(context: "worls") == nil)
        #expect(engine.evaluate(context: "kint") == nil)
        #expect(engine.evaluate(context: "woh") == nil)
    }

    // MARK: - Roadmap #2: context disambiguation
    @Test func previousWordBreaksChannelTies() {
        // Each token defers alone (two candidates tie in the cost cluster) and
        // commits once the previous word predicts exactly one of them.
        let engine = AutocorrectionEngine()
        #expect(engine.evaluate(context: "the worls")?.corrected == "world")
        #expect(engine.evaluate(context: "have dobe")?.corrected == "done")
    }

    @Test func contextReachesSystemDictionaryWords() {
        // Words the frequency lexicon may lack stay reachable through the
        // UITextChecker guess pool when context backs them.
        let engine = AutocorrectionEngine()
        #expect(engine.evaluate(context: "i slent")?.corrected == "spent")
    }

    @Test func contextRescuesShortTokens() {
        // "ny" is below the unigram length floor; only a decisive previous word
        // ("spent my") lets it commit.
        let engine = AutocorrectionEngine()
        #expect(engine.evaluate(context: "spent ny")?.corrected == "my")
    }

    @Test func contextWithoutSignalStillDefers() {
        // A previous word that predicts none of the candidates gives no signal,
        // so an ambiguous token is still left alone.
        let engine = AutocorrectionEngine()
        #expect(engine.evaluate(context: "purple hoke") == nil)
    }
}
