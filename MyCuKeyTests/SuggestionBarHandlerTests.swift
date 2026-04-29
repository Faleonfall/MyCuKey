import Testing
import UIKit
@testable import MyCuKey

// MARK: - Suggestion Bar Handler Tests

@MainActor
struct SuggestionBarHandlerTests {

    @Test func testSuggestionContextParsesCurrentToken() async throws {
        let context = try #require(SuggestionContext.parse("hello teh"))
        let token = try #require(context.token)

        #expect(context.mode == .currentToken)
        #expect(token.original == "teh")
        #expect(context.previousTokens == ["hello"])
        #expect(!context.isAtSentenceStart)
    }

    @Test func testSuggestionContextParsesNextWordAfterSpace() async throws {
        let context = try #require(SuggestionContext.parse("How are "))

        #expect(context.mode == .nextWord)
        #expect(context.previousTokens == ["how", "are"])
        #expect(!context.isAtSentenceStart)
        #expect(context.predictionInsertionPrefix == "")
        #expect(context.trailingBoundary == " ")
    }

    @Test func testSuggestionContextParsesNextWordAfterPunctuation() async throws {
        let context = try #require(SuggestionContext.parse("Hello."))

        #expect(context.mode == .nextWord)
        #expect(context.previousTokens == [])
        #expect(context.isAtSentenceStart)
        #expect(context.predictionInsertionPrefix == " ")
        #expect(context.trailingBoundary == ".")
    }

    @Test func testSuggestionContextParsesSentenceStartAfterPunctuationSpaceAndNewline() async throws {
        let punctuationSpace = try #require(SuggestionContext.parse("Hello. "))
        let newline = try #require(SuggestionContext.parse("Hello\n"))

        #expect(punctuationSpace.mode == .nextWord)
        #expect(punctuationSpace.isAtSentenceStart)
        #expect(punctuationSpace.predictionInsertionPrefix == "")
        #expect(newline.mode == .nextWord)
        #expect(newline.isAtSentenceStart)
    }

    @Test func testSuggestionContextPreservesWrappedAndTrailingDecoratedTokens() async throws {
        let wrapped = try #require(SuggestionContext.parse("*teh*"))
        let wrappedToken = try #require(wrapped.token)
        let trailingQuote = try #require(SuggestionContext.parse("teh\""))
        let quoteToken = try #require(trailingQuote.token)

        #expect(wrapped.mode == .currentToken)
        #expect(wrappedToken.original == "*teh*")
        #expect(wrappedToken.correctionTarget == "teh")
        #expect(wrappedToken.leadingDecoration == "*")
        #expect(wrappedToken.trailingDecoration == "*")
        #expect(quoteToken.original == "teh\"")
        #expect(quoteToken.trailingDecoration == "\"")
    }

    @Test func testHandlerPopulatesSuggestionBarForAlphabeticTyping() async throws {
        let handler = KeyboardActionHandler(personalDictionaryService: makeIsolatedService())
        let controller = MockKeyboardController(beforeInput: "te")
        handler.controller = controller

        handler.insertText("h")

        #expect(handler.suggestionBarState?.originalToken == "teh")
        #expect(handler.suggestionBarState?.suggestions.first?.text == "The")
    }

    @Test func testHandlerPopulatesSuggestionBarForSingleLetterPrefix() async throws {
        let handler = KeyboardActionHandler(personalDictionaryService: makeIsolatedService())
        let controller = MockKeyboardController()
        handler.controller = controller

        handler.insertText("t")

        #expect(handler.suggestionBarState?.originalToken == "t")
        #expect(handler.suggestionBarState?.suggestions.map(\.text) == ["The", "This"])
    }

    @Test func testHandlerSurfacesPersonalDictionarySuggestion() async throws {
        let service = makeIsolatedService()
        _ = service.addWord("mycustomword")
        let handler = KeyboardActionHandler(personalDictionaryService: service)
        let controller = MockKeyboardController(beforeInput: "hello myc")
        handler.controller = controller

        handler.refreshSuggestions(for: controller.mockProxy.documentContextBeforeInput)

        #expect(handler.suggestionBarState?.suggestions.first?.text == "mycustomword")
        #expect(handler.suggestionBarState?.suggestions.map(\.text).contains("mycustomword") == true)
    }

    @Test func testHandlerClearsSuggestionBarOutsideAlphabeticMode() async throws {
        let handler = KeyboardActionHandler(personalDictionaryService: makeIsolatedService())
        let controller = MockKeyboardController(beforeInput: "te")
        handler.controller = controller

        handler.insertText("h")
        #expect(handler.suggestionBarState != nil)

        handler.currentKeyboardType = .numeric

        #expect(handler.suggestionBarState == nil)
    }

    @Test func testHandlerRepopulatesSuggestionBarWhenReturningToAlphabeticMode() async throws {
        let handler = KeyboardActionHandler(personalDictionaryService: makeIsolatedService())
        let controller = MockKeyboardController(beforeInput: "teh")
        handler.controller = controller

        handler.currentKeyboardType = .numeric
        #expect(handler.suggestionBarState == nil)

        handler.currentKeyboardType = .alphabetic

        #expect(handler.suggestionBarState?.originalToken == "teh")
        #expect(handler.suggestionBarState?.suggestions.first?.text == "The")
    }

    @Test func testHandlerAppliesBestSuggestionToCurrentToken() async throws {
        let handler = KeyboardActionHandler(personalDictionaryService: makeIsolatedService())
        let controller = MockKeyboardController(beforeInput: "teh")
        handler.controller = controller
        handler.refreshSuggestions(for: controller.mockProxy.documentContextBeforeInput)

        let bestSuggestion = try #require(handler.suggestionBarState?.suggestions.first)
        handler.applySuggestion(bestSuggestion)

        #expect(controller.mockProxy.documentContextBeforeInput == "The ")
        #expect(handler.suggestionBarState == nil)
        #expect(handler.suppressSuggestionRefreshUntilNextToken)
    }

    @Test func testHandlerOriginalSuggestionKeepsCurrentToken() async throws {
        let handler = KeyboardActionHandler(personalDictionaryService: makeIsolatedService())
        let controller = MockKeyboardController(beforeInput: "teh")
        handler.controller = controller
        handler.refreshSuggestions(for: controller.mockProxy.documentContextBeforeInput)

        handler.applyOriginalSuggestion()

        #expect(controller.mockProxy.documentContextBeforeInput == "teh ")
        #expect(handler.suggestionBarState == nil)
        #expect(handler.suppressSuggestionRefreshUntilNextToken)
    }

    @Test func testHandlerRefreshesSuggestionsAfterDelete() async throws {
        let handler = KeyboardActionHandler(personalDictionaryService: makeIsolatedService())
        let controller = MockKeyboardController(beforeInput: "teht")
        handler.controller = controller
        handler.refreshSuggestions(for: controller.mockProxy.documentContextBeforeInput)

        #expect(handler.suggestionBarState?.originalToken == "teht")

        handler.deleteBackward()

        #expect(controller.mockProxy.documentContextBeforeInput == "teh")
        #expect(handler.suggestionBarState?.originalToken == "teh")
        #expect(handler.suggestionBarState?.suggestions.first?.text == "The")
    }

    @Test func testHandlerRefreshesSuggestionsWhenCurrentTokenChangesByTyping() async throws {
        let handler = KeyboardActionHandler(personalDictionaryService: makeIsolatedService())
        let controller = MockKeyboardController(beforeInput: "teh")
        handler.controller = controller
        handler.refreshSuggestions(for: controller.mockProxy.documentContextBeforeInput)

        #expect(handler.suggestionBarState?.originalToken == "teh")

        handler.insertText("t")

        #expect(controller.mockProxy.documentContextBeforeInput == "teht")
        #expect(handler.suggestionBarState?.originalToken == "teht")
    }

    @Test func testHandlerSwitchesToNextWordSuggestionsAfterSpace() async throws {
        let handler = KeyboardActionHandler(personalDictionaryService: makeIsolatedService())
        let controller = MockKeyboardController(beforeInput: "I")
        handler.controller = controller

        handler.insertText(" ")

        #expect(controller.mockProxy.documentContextBeforeInput == "I ")
        #expect(handler.suggestionBarState?.mode == .nextWord)
        let predictions = handler.suggestionBarState.map { Array($0.cells.map(\.text).prefix(3)) } ?? []
        #expect(predictions == ["think", "have", "am"])
        #expect(handler.suggestionBarState?.trailingSuffix == " ")
    }

    @Test func testHandlerAppliesPredictionAfterSpace() async throws {
        let handler = KeyboardActionHandler(personalDictionaryService: makeIsolatedService())
        let controller = MockKeyboardController(beforeInput: "How are ")
        handler.controller = controller

        handler.refreshSuggestions(for: controller.mockProxy.documentContextBeforeInput)
        let bestCell = try #require(handler.suggestionBarState?.cells.first)

        handler.applyCell(bestCell)

        #expect(bestCell.text == "you")
        #expect(controller.mockProxy.documentContextBeforeInput == "How are you ")
        #expect(handler.suggestionBarState?.mode == .nextWord)
        #expect(!handler.suppressSuggestionRefreshUntilNextToken)
    }

    @Test func testHandlerAppliesPredictionAfterSentencePunctuation() async throws {
        let handler = KeyboardActionHandler(personalDictionaryService: makeIsolatedService())
        let controller = MockKeyboardController(beforeInput: "Hello.")
        handler.controller = controller

        handler.refreshSuggestions(for: controller.mockProxy.documentContextBeforeInput)
        let bestCell = try #require(handler.suggestionBarState?.cells.first)

        handler.applyCell(bestCell)

        #expect(bestCell.text == "I")
        #expect(controller.mockProxy.documentContextBeforeInput == "Hello. I ")
        #expect(handler.suggestionBarState?.mode == .nextWord)
    }

    @Test func testHandlerConsumesPredictionSpaceBeforePunctuation() async throws {
        let handler = KeyboardActionHandler(personalDictionaryService: makeIsolatedService())
        let controller = MockKeyboardController(beforeInput: "How are ")
        handler.controller = controller

        handler.refreshSuggestions(for: controller.mockProxy.documentContextBeforeInput)
        let bestCell = try #require(handler.suggestionBarState?.cells.first)
        handler.applyCell(bestCell)

        handler.insertText("?")

        #expect(controller.mockProxy.documentContextBeforeInput == "How are you?")
    }

    @Test func testHandlerConsumesSuggestionSpaceBeforePunctuation() async throws {
        let handler = KeyboardActionHandler(personalDictionaryService: makeIsolatedService())
        let controller = MockKeyboardController(beforeInput: "teh")
        handler.controller = controller
        handler.refreshSuggestions(for: controller.mockProxy.documentContextBeforeInput)

        let bestSuggestion = try #require(handler.suggestionBarState?.suggestions.first)
        handler.applySuggestion(bestSuggestion)
        #expect(controller.mockProxy.documentContextBeforeInput == "The ")

        handler.insertText("?")

        #expect(controller.mockProxy.documentContextBeforeInput == "The?")
    }

    @Test func testHandlerRequiresTwoUserSpacesAfterSuggestionForPeriodShortcut() async throws {
        let handler = KeyboardActionHandler(personalDictionaryService: makeIsolatedService())
        let controller = MockKeyboardController(beforeInput: "teh")
        handler.controller = controller
        handler.refreshSuggestions(for: controller.mockProxy.documentContextBeforeInput)

        let bestSuggestion = try #require(handler.suggestionBarState?.suggestions.first)
        handler.applySuggestion(bestSuggestion)
        #expect(controller.mockProxy.documentContextBeforeInput == "The ")

        handler.insertText(" ")
        #expect(controller.mockProxy.documentContextBeforeInput == "The  ")

        handler.insertText(" ")

        #expect(controller.mockProxy.documentContextBeforeInput == "The. ")
    }

    @Test func testHandlerSuggestionSpaceOnlyBecomesPeriodAfterQuickSecondUserSpace() async throws {
        let handler = KeyboardActionHandler(personalDictionaryService: makeIsolatedService())
        let controller = MockKeyboardController(beforeInput: "teh")
        handler.controller = controller
        handler.refreshSuggestions(for: controller.mockProxy.documentContextBeforeInput)

        let bestSuggestion = try #require(handler.suggestionBarState?.suggestions.first)
        handler.applySuggestion(bestSuggestion)
        handler.insertText(" ")

        #expect(handler.pendingSuggestionCommittedSpace)
        #expect(handler.pendingSuggestionSpaceTapCount == 1)
        #expect(controller.mockProxy.documentContextBeforeInput == "The  ")
    }

    @Test func testHandlerSuggestionsIgnoreLeadingQuote() async throws {
        let handler = KeyboardActionHandler(personalDictionaryService: makeIsolatedService())
        let controller = MockKeyboardController(beforeInput: "\"teh")
        handler.controller = controller

        handler.refreshSuggestions(for: controller.mockProxy.documentContextBeforeInput)

        #expect(handler.suggestionBarState?.originalToken == "\"teh")
        #expect(handler.suggestionBarState?.suggestions.first?.text == "The")
    }

    @Test func testHandlerAppliesSuggestionInsideLeadingStarWrapper() async throws {
        let handler = KeyboardActionHandler(personalDictionaryService: makeIsolatedService())
        let controller = MockKeyboardController(beforeInput: "*teh")
        handler.controller = controller

        handler.refreshSuggestions(for: controller.mockProxy.documentContextBeforeInput)
        let bestSuggestion = try #require(handler.suggestionBarState?.suggestions.first)

        handler.applySuggestion(bestSuggestion)

        #expect(controller.mockProxy.documentContextBeforeInput == "*The ")
        #expect(handler.suggestionBarState == nil)
    }

    @Test func testHandlerSuggestionsIgnoreTrailingQuote() async throws {
        let handler = KeyboardActionHandler(personalDictionaryService: makeIsolatedService())
        let controller = MockKeyboardController(beforeInput: "teh\"")
        handler.controller = controller

        handler.refreshSuggestions(for: controller.mockProxy.documentContextBeforeInput)

        #expect(handler.suggestionBarState?.originalToken == "teh\"")
        #expect(handler.suggestionBarState?.suggestions.first?.text == "The")
    }

    @Test func testHandlerAppliesSuggestionInsideSymmetricStarWrapper() async throws {
        let handler = KeyboardActionHandler(personalDictionaryService: makeIsolatedService())
        let controller = MockKeyboardController(beforeInput: "*teh*")
        handler.controller = controller

        handler.refreshSuggestions(for: controller.mockProxy.documentContextBeforeInput)
        let bestSuggestion = try #require(handler.suggestionBarState?.suggestions.first)

        handler.applySuggestion(bestSuggestion)

        #expect(controller.mockProxy.documentContextBeforeInput == "*The* ")
        #expect(handler.suggestionBarState == nil)
    }
}
