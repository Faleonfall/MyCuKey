import Testing
import UIKit
@testable import MyCuKey

// Roadmap #1: decoder-driven silent auto-apply. The trie noisy-channel decoder
// may commit a fix only when the winning repair is unambiguous (alone at its
// edit distance) and the typed token is not a real or intentional word. These
// tests lock both the wins and the trust guards that keep it safe.
@MainActor
struct DecoderAutoApplyTests {
    @Test func commitsUnambiguousFatFingerCorrections() {
        // Each target is effectively alone one edit from the typo, so it commits
        // even with no surrounding context.
        let engine = AutocorrectionEngine()
        #expect(engine.evaluate(context: "peoole")?.corrected == "people")
        #expect(engine.evaluate(context: "dobe")?.corrected == "done")
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
        // "kint" (hint/mint/kind...) and "fivd" (five/find) each sit one edit from
        // several real words; with no previous word the decoder defers.
        let engine = AutocorrectionEngine()
        #expect(engine.evaluate(context: "kint") == nil)
        #expect(engine.evaluate(context: "fivd") == nil)
    }

    // MARK: - Roadmap #2: context disambiguation

    @Test func previousWordBreaksEditDistanceTies() {
        let engine = AutocorrectionEngine()
        #expect(engine.evaluate(context: "fifty fivd")?.corrected == "five")
    }

    @Test func contextReachesInflectionsMissingFromLexicon() {
        // "spent" is absent from the frequency lexicon but known to the system
        // dictionary; context makes it reachable.
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
        #expect(engine.evaluate(context: "purple fivd") == nil)
    }
}
