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

    @Test func testAutocorrectionRejectsWeakDistanceTwoGuess() async throws {
        let engine = AutocorrectionEngine()
        #expect(engine.evaluate(context: "definatly") == nil)
    }

    @Test func testAutocorrectionSkipsExpressiveTrailingRepeatedLetters() async throws {
        let engine = AutocorrectionEngine()
        #expect(engine.evaluate(context: "nooo") == nil)
    }

    @Test func testAutocorrectionStillFixesRoleplayWrappedPlainWord() async throws {
        let engine = AutocorrectionEngine()
        #expect(engine.evaluate(context: "*teh*")?.corrected == "*the*")
    }

    @Test func testAutocorrectionFixesCuratedCommonMistakes() async throws {
        let engine = AutocorrectionEngine()
        #expect(engine.evaluate(context: "becase")?.corrected == "because")
        #expect(engine.evaluate(context: "wierd")?.corrected == "weird")
        #expect(engine.evaluate(context: "agian")?.corrected == "again")
    }

    @Test func testAutocorrectionFixesRealWorldTypingMistakes() async throws {
        let engine = AutocorrectionEngine()
        #expect(engine.evaluate(context: "actaully")?.corrected == "actually")
        #expect(engine.evaluate(context: "diffrent")?.corrected == "different")
        #expect(engine.evaluate(context: "intresting")?.corrected == "interesting")
        #expect(engine.evaluate(context: "chekc")?.corrected == "check")
        #expect(engine.evaluate(context: "anyhting")?.corrected == "anything")
        #expect(engine.evaluate(context: "usaully")?.corrected == "usually")
        #expect(engine.evaluate(context: "keeo")?.corrected == "keep")
        #expect(engine.evaluate(context: "ot")?.corrected == "on")
    }

    @Test func testAutocorrectionFixesSafeNearbyKeySubstitutions() async throws {
        let engine = AutocorrectionEngine()
        #expect(engine.evaluate(context: "mot")?.corrected == "not")
        #expect(engine.evaluate(context: "vome")?.corrected == "come")
        #expect(engine.evaluate(context: "yur")?.corrected == "your")
        #expect(engine.evaluate(context: "Okey")?.corrected == "Okay")
    }

    @Test func testAutocorrectionFixesMergedAndApostropheForms() async throws {
        let engine = AutocorrectionEngine()
        #expect(engine.evaluate(context: "noone")?.corrected == "no one")
        #expect(engine.evaluate(context: "herrs")?.corrected == "here's")
        #expect(engine.evaluate(context: "Herrs")?.corrected == "Here's")
    }

    @Test func testAutocorrectionSuggestionsExposeRankedCandidates() async throws {
        let engine = AutocorrectionEngine()
        let suggestionSet = engine.suggestions(context: "teh")
        #expect(suggestionSet?.token.original == "teh")
        #expect(suggestionSet?.suggestions.first?.text == "the")
        #expect(suggestionSet?.suggestions.first?.kind == .candidate)
        #expect((suggestionSet?.suggestions.count ?? 0) >= 1)
    }

    @Test func testAutocorrectionSuggestionsReturnSafeLocalMatch() async throws {
        let engine = AutocorrectionEngine()
        #expect(engine.suggestions(context: "yur")?.suggestions.first?.text == "your")
    }

    @Test func testAutocorrectionSuggestionsCanSurfaceHelpfulAlternativesForWordLikeInput() async throws {
        let engine = AutocorrectionEngine()
        let suggestions = engine.suggestions(context: "herr")?.suggestions.map(\.text) ?? []
        #expect(!suggestions.isEmpty)
        #expect(suggestions.count <= 2)
    }

    @Test func testAutocorrectionSuggestionsDeduplicateEquivalentCandidates() async throws {
        let engine = AutocorrectionEngine()
        let suggestions = engine.suggestions(context: "teh")?.suggestions.map(\.text) ?? []
        #expect(Set(suggestions).count == suggestions.count)
        #expect(suggestions.count <= 2)
    }

    @Test func testAutocorrectionLeavesAmbiguousNearbyOrDuplicateCasesAlone() async throws {
        let engine = AutocorrectionEngine()
        #expect(engine.evaluate(context: "woh") == nil)
        #expect(engine.evaluate(context: "yourr") == nil)
        #expect(engine.evaluate(context: "mind") == nil)
        #expect(engine.evaluate(context: "herr") == nil)
        #expect(engine.evaluate(context: "kint") == nil)
        #expect(engine.evaluate(context: "csb") == nil)
    }

    @Test func testAutocorrectionLeavesHeavilyCorruptedWordAlone() async throws {
        let engine = AutocorrectionEngine()
        #expect(engine.evaluate(context: "gethtett") == nil)
    }
}
