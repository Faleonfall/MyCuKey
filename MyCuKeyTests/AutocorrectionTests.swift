import Testing
import Foundation
@testable import MyCuKey

@MainActor
struct AutocorrectionTests {

    @Test func testEditDistanceIdentical() async throws {
        let engine = AutocorrectionEngine()
        #expect(engine.editDistance("hello", "hello") == 0)
    }

    @Test func testEditDistanceSingleMissingLetter() async throws {
        let engine = AutocorrectionEngine()
        #expect(engine.editDistance("helo", "hello") == 1)
    }

    @Test func testEditDistanceSingleExtraLetter() async throws {
        let engine = AutocorrectionEngine()
        #expect(engine.editDistance("helloo", "hello") == 1)
    }

    @Test func testLevenshteinCountsTranspositionAsTwoEdits() async throws {
        let engine = AutocorrectionEngine()
        #expect(engine.editDistance("hlelo", "hello") == 2)
    }

    @Test func testDamerauTreatsTranspositionAsOneEdit() async throws {
        let engine = AutocorrectionEngine()
        #expect(engine.damerauLevenshteinDistance("teh", "the") == 1)
    }

    @Test func testCommonWordLexiconContainsExpectedEntries() async throws {
        #expect(CommonWordLexicon.contains("hello"))
        #expect(CommonWordLexicon.contains("keyboard"))
        #expect(CommonWordLexicon.contains("because"))
    }

    @Test func testAutocorrectionSkipsSingleChar() async throws {
        let engine = AutocorrectionEngine()
        #expect(engine.evaluate(context: "x") == nil)
    }

    @Test func testAutocorrectionSkipsCorrectWord() async throws {
        let engine = AutocorrectionEngine()
        #expect(engine.evaluate(context: "hello") == nil)
    }

    @Test func testAutocorrectionSkipsEmptyContext() async throws {
        let engine = AutocorrectionEngine()
        #expect(engine.evaluate(context: "") == nil)
    }

    @Test func testAutocorrectionFixesTransposition() async throws {
        let engine = AutocorrectionEngine()
        let result = engine.evaluate(context: "teh")
        #expect(result?.corrected == "the")
        #expect(result?.source == .deterministicRule || result?.source == .textChecker)
    }

    @Test func testAutocorrectionFixesMissingLetter() async throws {
        let engine = AutocorrectionEngine()
        let result = engine.evaluate(context: "helo")
        #expect(result?.corrected == "hello")
        #expect(result?.charsToDelete == 4)
    }

    @Test func testAutocorrectionFixesExtraLetter() async throws {
        let engine = AutocorrectionEngine()
        let result = engine.evaluate(context: "helllo")
        #expect(result?.corrected == "hello")
    }

    @Test func testAutocorrectionFixesRepeatedLetters() async throws {
        let engine = AutocorrectionEngine()
        let result = engine.evaluate(context: "goood")
        #expect(result?.corrected == "good")
        #expect(result?.source == .deterministicRule)
    }

    @Test func testAutocorrectionRestoresApostropheThroughChecker() async throws {
        let engine = AutocorrectionEngine()
        let result = engine.evaluate(context: "ive")
        #expect(result?.corrected == "I've")
    }

    @Test func testAutocorrectionPreservesCapitalization() async throws {
        let engine = AutocorrectionEngine()
        #expect(engine.evaluate(context: "Teh")?.corrected == "The")
        #expect(engine.evaluate(context: "TEH")?.corrected == "THE")
    }

    @Test func testAutocorrectionRejectsAmbiguousShortWords() async throws {
        let engine = AutocorrectionEngine()
        #expect(engine.evaluate(context: "ill") == nil)
        #expect(engine.evaluate(context: "usr") == nil)
    }

    @Test func testDistanceTwoStillAcceptsLikelyWordShape() async throws {
        let engine = AutocorrectionEngine()
        #expect(engine.evaluate(context: "becase")?.corrected == "because")
    }
}
