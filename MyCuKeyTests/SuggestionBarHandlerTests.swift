import Testing
import UIKit
@testable import MyCuKey

// MARK: - Suggestion Bar Handler Tests

@MainActor
struct SuggestionBarHandlerTests {

    @Test func testHandlerPopulatesSuggestionBarForAlphabeticTyping() async throws {
        let handler = KeyboardActionHandler(personalDictionaryService: makeIsolatedService())
        let controller = MockKeyboardController(beforeInput: "te")
        handler.controller = controller

        handler.insertText("h")

        #expect(handler.suggestionBarState?.originalToken == "teh")
        #expect(handler.suggestionBarState?.suggestions.first?.text == "the")
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
        #expect(handler.suggestionBarState?.suggestions.first?.text == "the")
    }

    @Test func testHandlerAppliesBestSuggestionToCurrentToken() async throws {
        let handler = KeyboardActionHandler(personalDictionaryService: makeIsolatedService())
        let controller = MockKeyboardController(beforeInput: "teh")
        handler.controller = controller
        handler.refreshSuggestions(for: controller.mockProxy.documentContextBeforeInput)

        let bestSuggestion = try #require(handler.suggestionBarState?.suggestions.first)
        handler.applySuggestion(bestSuggestion)

        #expect(controller.mockProxy.documentContextBeforeInput == "the ")
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
        #expect(handler.suggestionBarState?.suggestions.first?.text == "the")
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

    @Test func testHandlerKeepsSuggestionsAvailableAfterSpaceForPreviousToken() async throws {
        let handler = KeyboardActionHandler(personalDictionaryService: makeIsolatedService())
        let controller = MockKeyboardController(beforeInput: "teht")
        handler.controller = controller

        handler.insertText(" ")

        #expect(controller.mockProxy.documentContextBeforeInput == "teht ")
        #expect(handler.suggestionBarState?.originalToken == "teht")
        #expect(!(handler.suggestionBarState?.suggestions.isEmpty ?? true))
        #expect(handler.suggestionBarState?.trailingSuffix == " ")
    }

    @Test func testHandlerAppliesSuggestionToPreviousTokenAfterSpace() async throws {
        let handler = KeyboardActionHandler(personalDictionaryService: makeIsolatedService())
        let controller = MockKeyboardController(beforeInput: "teht")
        handler.controller = controller

        handler.insertText(" ")
        let bestSuggestion = try #require(handler.suggestionBarState?.suggestions.first)

        handler.applySuggestion(bestSuggestion)

        #expect(controller.mockProxy.documentContextBeforeInput == "\(bestSuggestion.text) ")
        #expect(handler.suggestionBarState == nil)
        #expect(handler.suppressSuggestionRefreshUntilNextToken)
    }

    @Test func testHandlerConsumesSuggestionSpaceBeforePunctuation() async throws {
        let handler = KeyboardActionHandler(personalDictionaryService: makeIsolatedService())
        let controller = MockKeyboardController(beforeInput: "teh")
        handler.controller = controller
        handler.refreshSuggestions(for: controller.mockProxy.documentContextBeforeInput)

        let bestSuggestion = try #require(handler.suggestionBarState?.suggestions.first)
        handler.applySuggestion(bestSuggestion)
        #expect(controller.mockProxy.documentContextBeforeInput == "the ")

        handler.insertText("?")

        #expect(controller.mockProxy.documentContextBeforeInput == "the?")
    }

    @Test func testHandlerRequiresTwoUserSpacesAfterSuggestionForPeriodShortcut() async throws {
        let handler = KeyboardActionHandler(personalDictionaryService: makeIsolatedService())
        let controller = MockKeyboardController(beforeInput: "teh")
        handler.controller = controller
        handler.refreshSuggestions(for: controller.mockProxy.documentContextBeforeInput)

        let bestSuggestion = try #require(handler.suggestionBarState?.suggestions.first)
        handler.applySuggestion(bestSuggestion)
        #expect(controller.mockProxy.documentContextBeforeInput == "the ")

        handler.insertText(" ")
        #expect(controller.mockProxy.documentContextBeforeInput == "the  ")

        handler.insertText(" ")

        #expect(controller.mockProxy.documentContextBeforeInput == "the. ")
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
        #expect(controller.mockProxy.documentContextBeforeInput == "the  ")
    }

    @Test func testHandlerSuggestionsIgnoreLeadingQuote() async throws {
        let handler = KeyboardActionHandler(personalDictionaryService: makeIsolatedService())
        let controller = MockKeyboardController(beforeInput: "\"teh")
        handler.controller = controller

        handler.refreshSuggestions(for: controller.mockProxy.documentContextBeforeInput)

        #expect(handler.suggestionBarState?.originalToken == "\"teh")
        #expect(handler.suggestionBarState?.suggestions.first?.text == "the")
    }

    @Test func testHandlerAppliesSuggestionInsideLeadingStarWrapper() async throws {
        let handler = KeyboardActionHandler(personalDictionaryService: makeIsolatedService())
        let controller = MockKeyboardController(beforeInput: "*teh")
        handler.controller = controller

        handler.refreshSuggestions(for: controller.mockProxy.documentContextBeforeInput)
        let bestSuggestion = try #require(handler.suggestionBarState?.suggestions.first)

        handler.applySuggestion(bestSuggestion)

        #expect(controller.mockProxy.documentContextBeforeInput == "*the ")
        #expect(handler.suggestionBarState == nil)
    }

    @Test func testHandlerSuggestionsIgnoreTrailingQuote() async throws {
        let handler = KeyboardActionHandler(personalDictionaryService: makeIsolatedService())
        let controller = MockKeyboardController(beforeInput: "teh\"")
        handler.controller = controller

        handler.refreshSuggestions(for: controller.mockProxy.documentContextBeforeInput)

        #expect(handler.suggestionBarState?.originalToken == "teh\"")
        #expect(handler.suggestionBarState?.suggestions.first?.text == "the")
    }

    @Test func testHandlerAppliesSuggestionInsideSymmetricStarWrapper() async throws {
        let handler = KeyboardActionHandler(personalDictionaryService: makeIsolatedService())
        let controller = MockKeyboardController(beforeInput: "*teh*")
        handler.controller = controller

        handler.refreshSuggestions(for: controller.mockProxy.documentContextBeforeInput)
        let bestSuggestion = try #require(handler.suggestionBarState?.suggestions.first)

        handler.applySuggestion(bestSuggestion)

        #expect(controller.mockProxy.documentContextBeforeInput == "*the* ")
        #expect(handler.suggestionBarState == nil)
    }
}
