import Testing
import Foundation
@testable import MyCuKey

// MARK: - Autocorrection Engine Tests

@MainActor
struct AutocorrectionTests {

    // MARK: - Distance Metrics

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

    // MARK: - Auto-Apply Behavior

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

    // MARK: - Suggestion Behavior

    @Test func testAutocorrectionSuggestionsExposeRankedCandidates() async throws {
        let engine = AutocorrectionEngine()
        let suggestionSet = engine.suggestions(context: "teh")
        #expect(suggestionSet?.token.original == "teh")
        #expect(suggestionSet?.suggestions.first?.text == "The")
        #expect((suggestionSet?.suggestions.count ?? 0) >= 1)
    }

    @Test func testAutocorrectionSuggestionsReturnSafeLocalMatch() async throws {
        let engine = AutocorrectionEngine()
        #expect(engine.suggestions(context: "yur")?.suggestions.first?.text == "Your")
    }

    @Test func testAutocorrectionSuggestionsSurfaceShortPrefixCompletions() async throws {
        let engine = AutocorrectionEngine()

        let singleLetterSuggestions = engine.suggestions(context: "t")?.suggestions.map(\.text) ?? []
        #expect(singleLetterSuggestions == ["The", "This"])

        let twoLetterSuggestions = engine.suggestions(context: "th")?.suggestions.map(\.text) ?? []
        #expect(twoLetterSuggestions == ["The", "This"])
    }

    @Test func testAutocorrectionSuggestionsUseCuratedTinyPrefixRanking() async throws {
        let engine = AutocorrectionEngine()

        let midSentenceTh = engine.suggestions(context: "hello th")?.suggestions.map(\.text) ?? []
        let sentenceStartYo = engine.suggestions(context: "yo")?.suggestions.map(\.text) ?? []
        let afterI = engine.suggestions(context: "I th")?.suggestions.map(\.text) ?? []

        #expect(midSentenceTh == ["the", "that"])
        #expect(sentenceStartYo == ["You", "Your"])
        #expect(afterI.first == "think")
    }

    @Test func testAutocorrectionSuggestionsKeepTinyWordsCommonAndLocal() async throws {
        let engine = AutocorrectionEngine()

        let heSuggestions = engine.suggestions(
            context: "hello he",
            boostedTerms: [SuggestionBoostTerm(word: "henrique", source: .supplementaryLexicon)]
        )?.suggestions.map(\.text) ?? []
        let meSuggestions = engine.suggestions(
            context: "hello me",
            boostedTerms: [SuggestionBoostTerm(word: "mendonca", source: .supplementaryLexicon)]
        )?.suggestions.map(\.text) ?? []

        #expect(heSuggestions == ["her", "here"])
        #expect(meSuggestions == ["mean", "message"])
        #expect(!heSuggestions.contains("henrique"))
        #expect(!meSuggestions.contains("mendonca"))
    }

    @Test func testAutocorrectionSuggestionsGatePersonalDictionaryForTinyPrefixes() async throws {
        let engine = AutocorrectionEngine()
        let boostedTerms = [SuggestionBoostTerm(word: "mycustomword", source: .personalDictionary)]

        let twoLetterSuggestions = engine.suggestions(
            context: "hello my",
            boostedTerms: boostedTerms
        )?.suggestions.map(\.text) ?? []
        let threeLetterSuggestions = engine.suggestions(
            context: "hello myc",
            boostedTerms: boostedTerms
        )?.suggestions.map(\.text) ?? []

        #expect(!twoLetterSuggestions.contains("mycustomword"))
        #expect(threeLetterSuggestions.first == "mycustomword")
    }

    @Test func testAutocorrectionSuggestionsHideWeakTinyPrefixFallbacks() async throws {
        let engine = AutocorrectionEngine()

        #expect(engine.suggestions(context: "hello zx") == nil)
        #expect(engine.suggestions(context: "qz") == nil)
    }

    @Test func testAutocorrectionSuggestionsKeepTinyRepairsCurated() async throws {
        let engine = AutocorrectionEngine()

        #expect(engine.suggestions(context: "teh")?.suggestions.first?.text == "The")
        #expect(engine.suggestions(context: "hello adn")?.suggestions.first?.text == "and")
        #expect(engine.suggestions(context: "hello yur")?.suggestions.first?.text == "your")
    }

    @Test func testAutocorrectionSuggestionsRepairLongerMisspellings() async throws {
        let engine = AutocorrectionEngine()
        let cases = [
            ("langauge", "language"),
            ("definatly", "definitely"),
            ("suggesstion", "suggestion"),
            ("autocorection", "autocorrection"),
            ("intresting", "interesting"),
            ("wotk", "work")
        ]

        for (input, expected) in cases {
            let suggestions = engine.suggestions(context: "please \(input)")?.suggestions.map(\.text) ?? []
            #expect(suggestions.contains(expected))
        }
    }

    @Test func testAutocorrectionSuggestionsRankKeyboardNeighborRepairFirst() async throws {
        let engine = AutocorrectionEngine()
        #expect(engine.suggestions(context: "please wotk")?.suggestions.first?.text == "work")
    }

    @Test func testAutocorrectionSuggestionsCanBoostPersonalTerms() async throws {
        let engine = AutocorrectionEngine()
        let suggestions = engine.suggestions(
            context: "hello myc",
            boostedTerms: [SuggestionBoostTerm(word: "mycustomword", source: .personalDictionary)]
        )?.suggestions.map(\.text) ?? []

        #expect(suggestions.first == "mycustomword")
        #expect(suggestions.contains("mycustomword"))
        #expect(!suggestions.contains("my"))
    }

    @Test func testAutocorrectionSuggestionsDoNotSurfaceSupplementaryNamesForTinyPrefixes() async throws {
        let engine = AutocorrectionEngine()

        let heSuggestions = engine.suggestions(
            context: "hello he",
            boostedTerms: [SuggestionBoostTerm(word: "henrique", source: .supplementaryLexicon)]
        )?.suggestions.map(\.text) ?? []
        let meSuggestions = engine.suggestions(
            context: "hello me",
            boostedTerms: [SuggestionBoostTerm(word: "mendonca", source: .supplementaryLexicon)]
        )?.suggestions.map(\.text) ?? []
        let longerPrefixSuggestions = engine.suggestions(
            context: "hello henr",
            boostedTerms: [SuggestionBoostTerm(word: "henrique", source: .supplementaryLexicon)]
        )?.suggestions.map(\.text) ?? []

        #expect(!heSuggestions.contains("henrique"))
        #expect(!meSuggestions.contains("mendonca"))
        #expect(longerPrefixSuggestions.contains("henrique"))
    }

    @Test func testAutocorrectionSuggestionsCanSurfaceHelpfulAlternativesForWordLikeInput() async throws {
        let engine = AutocorrectionEngine()
        let suggestions = engine.suggestions(context: "herr")?.suggestions.map(\.text) ?? []
        #expect(!suggestions.isEmpty)
        #expect(suggestions.count <= 2)
    }

    @Test func testAutocorrectionSuggestionsCanSurfaceLongerWordAlternativesWithoutAutoApplying() async throws {
        let engine = AutocorrectionEngine()
        #expect(engine.evaluate(context: "definatly") == nil)

        let suggestions = engine.suggestions(context: "please definatly")?.suggestions.map(\.text) ?? []
        #expect(suggestions.first == "definitely")
        #expect(suggestions.contains("definitely"))
    }

    @Test func testNextWordSuggestionsUseSentenceAndPhraseContext() async throws {
        let provider = NextWordSuggestionProvider()

        let afterI = try #require(SuggestionContext.parse("I "))
        let afterPhrase = try #require(SuggestionContext.parse("How are "))
        let afterSentence = try #require(SuggestionContext.parse(". "))

        #expect(provider.suggestions(for: afterI).map(\.text) == ["think", "have", "am"])
        #expect(provider.suggestions(for: afterPhrase).first?.text == "you")
        #expect(Array(provider.suggestions(for: afterSentence).map(\.text).prefix(3)) == ["I", "The", "You"])
    }

    @Test func testAutocorrectionSuggestionsDeduplicateEquivalentCandidates() async throws {
        let engine = AutocorrectionEngine()
        let suggestions = engine.suggestions(context: "teh")?.suggestions.map(\.text) ?? []
        #expect(Set(suggestions).count == suggestions.count)
        #expect(suggestions.count <= 2)
    }

    @Test func testAutocorrectionSuggestionsHandleWrappedTokenContext() async throws {
        let engine = AutocorrectionEngine()
        #expect(engine.suggestions(context: "*teh*")?.suggestions.first?.text == "*The*")
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
