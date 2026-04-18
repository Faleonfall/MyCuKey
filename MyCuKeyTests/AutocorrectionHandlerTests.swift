import Testing
import UIKit
@testable import MyCuKey

@MainActor
struct AutocorrectionHandlerTests {

    @Test func testHandlerPreservesQuestionMarkAfterAutocorrection() async throws {
        let handler = KeyboardActionHandler(personalDictionaryService: makeIsolatedService())
        let controller = MockKeyboardController(beforeInput: "teh")
        handler.controller = controller

        handler.insertText("?")

        #expect(controller.mockProxy.documentContextBeforeInput == "the?")
    }

    @Test func testHandlerUsesContractionBeforeGenericAutocorrection() async throws {
        let handler = KeyboardActionHandler(personalDictionaryService: makeIsolatedService())
        let controller = MockKeyboardController(beforeInput: "im")
        handler.controller = controller

        handler.insertText(" ")

        #expect(controller.mockProxy.documentContextBeforeInput == "I'm ")
    }

    @Test func testHandlerLeavesWeakGuessAlone() async throws {
        let handler = KeyboardActionHandler(personalDictionaryService: makeIsolatedService())
        let controller = MockKeyboardController(beforeInput: "usr")
        handler.controller = controller

        handler.insertText(" ")

        #expect(controller.mockProxy.documentContextBeforeInput == "usr ")
    }

    @Test func testHandlerCorrectsRoleplayWrappedPlainWord() async throws {
        let handler = KeyboardActionHandler(personalDictionaryService: makeIsolatedService())
        let controller = MockKeyboardController(beforeInput: "*teh*")
        handler.controller = controller

        handler.insertText(" ")

        #expect(controller.mockProxy.documentContextBeforeInput == "*the* ")
    }

    @Test func testHandlerPreservesQuestionMarkAfterDeterministicCuratedCorrection() async throws {
        let handler = KeyboardActionHandler(personalDictionaryService: makeIsolatedService())
        let controller = MockKeyboardController(beforeInput: "becase")
        handler.controller = controller

        handler.insertText("?")

        #expect(controller.mockProxy.documentContextBeforeInput == "because?")
    }

    @Test func testHandlerCorrectsSafeLocalTypoInsideSentenceContext() async throws {
        let handler = KeyboardActionHandler(personalDictionaryService: makeIsolatedService())
        let controller = MockKeyboardController(beforeInput: "I'm mot")
        handler.controller = controller

        handler.insertText(" ")

        #expect(controller.mockProxy.documentContextBeforeInput == "I'm not ")
    }

    @Test func testHandlerCorrectsAnotherSafeLocalTypoInsideSentenceContext() async throws {
        let handler = KeyboardActionHandler(personalDictionaryService: makeIsolatedService())
        let controller = MockKeyboardController(beforeInput: "Want to vome")
        handler.controller = controller

        handler.insertText("?")

        #expect(controller.mockProxy.documentContextBeforeInput == "Want to come?")
    }

    @Test func testHandlerLeavesAmbiguousWordAloneInsideSentenceContext() async throws {
        let handler = KeyboardActionHandler(personalDictionaryService: makeIsolatedService())
        let controller = MockKeyboardController(beforeInput: "but maybe yourr")
        handler.controller = controller

        handler.insertText(" ")

        #expect(controller.mockProxy.documentContextBeforeInput == "but maybe yourr ")
    }

    @Test func testStandaloneLowercaseIBecomesCapitalIWhenFollowedBySpace() async throws {
        let handler = KeyboardActionHandler(personalDictionaryService: makeIsolatedService())
        let controller = MockKeyboardController(beforeInput: " i")
        handler.controller = controller

        handler.insertText(" ")

        #expect(controller.mockProxy.documentContextBeforeInput == " I ")
    }

    @Test func testStandaloneLowercaseIAtStartBecomesCapitalIWhenFollowedBySpace() async throws {
        let handler = KeyboardActionHandler(personalDictionaryService: makeIsolatedService())
        let controller = MockKeyboardController(beforeInput: "i")
        handler.controller = controller

        handler.insertText(" ")

        #expect(controller.mockProxy.documentContextBeforeInput == "I ")
    }

    @Test func testStandaloneLowercaseIAfterOpeningParenthesisBecomesCapitalI() async throws {
        let handler = KeyboardActionHandler(personalDictionaryService: makeIsolatedService())
        let controller = MockKeyboardController(beforeInput: "(i")
        handler.controller = controller

        handler.insertText(" ")

        #expect(controller.mockProxy.documentContextBeforeInput == "(I ")
    }

    @Test func testStandaloneLowercaseIAfterQuoteBecomesCapitalI() async throws {
        let handler = KeyboardActionHandler(personalDictionaryService: makeIsolatedService())
        let controller = MockKeyboardController(beforeInput: "\"i")
        handler.controller = controller

        handler.insertText(" ")

        #expect(controller.mockProxy.documentContextBeforeInput == "\"I ")
    }

    @Test func testEmbeddedLowercaseIDoesNotBecomeCapitalI() async throws {
        let handler = KeyboardActionHandler(personalDictionaryService: makeIsolatedService())
        let controller = MockKeyboardController(beforeInput: "hi")
        handler.controller = controller

        handler.insertText(" ")

        #expect(controller.mockProxy.documentContextBeforeInput == "hi ")
    }

    @Test func testWordEndingInLowercaseIDoesNotBecomeCapitalI() async throws {
        let handler = KeyboardActionHandler(personalDictionaryService: makeIsolatedService())
        let controller = MockKeyboardController(beforeInput: "wifi")
        handler.controller = controller

        handler.insertText(" ")

        #expect(controller.mockProxy.documentContextBeforeInput == "wifi ")
    }

    @Test func testDeleteRevertsLastAutocorrectionWithSpace() async throws {
        let handler = KeyboardActionHandler(personalDictionaryService: makeIsolatedService())
        let controller = MockKeyboardController(beforeInput: "teh")
        handler.controller = controller

        handler.insertText(" ")
        #expect(controller.mockProxy.documentContextBeforeInput == "the ")

        handler.deleteBackward()
        #expect(controller.mockProxy.documentContextBeforeInput == "teh")
    }

    @Test func testDeleteRevertsLastAutocorrectionWithPunctuation() async throws {
        let handler = KeyboardActionHandler(personalDictionaryService: makeIsolatedService())
        let controller = MockKeyboardController(beforeInput: "teh")
        handler.controller = controller

        handler.insertText("?")
        #expect(controller.mockProxy.documentContextBeforeInput == "the?")

        handler.deleteBackward()
        #expect(controller.mockProxy.documentContextBeforeInput == "teh?")
    }

    @Test func testDeleteRevertsCuratedDeterministicCorrectionWithPunctuation() async throws {
        let handler = KeyboardActionHandler(personalDictionaryService: makeIsolatedService())
        let controller = MockKeyboardController(beforeInput: "becase")
        handler.controller = controller

        handler.insertText("?")
        #expect(controller.mockProxy.documentContextBeforeInput == "because?")

        handler.deleteBackward()
        #expect(controller.mockProxy.documentContextBeforeInput == "becase?")
    }

    @Test func testDeleteDoesNormalDeleteAfterContinuingTyping() async throws {
        let handler = KeyboardActionHandler(personalDictionaryService: makeIsolatedService())
        let controller = MockKeyboardController(beforeInput: "teh")
        handler.controller = controller

        handler.insertText(" ")
        handler.insertText("x")
        #expect(controller.mockProxy.documentContextBeforeInput == "the x")

        handler.deleteBackward()
        #expect(controller.mockProxy.documentContextBeforeInput == "the ")
    }

    @Test func testLearnedWordSuppressesFutureAutocorrection() async throws {
        let service = makeIsolatedService()
        _ = service.addWord("teh")

        let handler = KeyboardActionHandler(personalDictionaryService: service)
        let controller = MockKeyboardController(beforeInput: "teh")
        handler.controller = controller

        handler.insertText(" ")

        #expect(controller.mockProxy.documentContextBeforeInput == "teh ")
    }

    @Test func testLearnedWordSuppressesFutureCuratedDeterministicCorrection() async throws {
        let service = makeIsolatedService()
        _ = service.addWord("actaully")

        let handler = KeyboardActionHandler(personalDictionaryService: service)
        let controller = MockKeyboardController(beforeInput: "actaully")
        handler.controller = controller

        handler.insertText(" ")

        #expect(controller.mockProxy.documentContextBeforeInput == "actaully ")
    }

    @Test func testHandlerRefreshesLearnedWordsFromSharedStorageBeforeCorrection() async throws {
        let suiteName = "test.personal-dictionary.handler-refresh.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let service = PersonalDictionaryService(defaults: defaults)
        let handler = KeyboardActionHandler(personalDictionaryService: service)
        let externalService = PersonalDictionaryService(defaults: defaults)
        _ = externalService.addWord("teh")

        let controller = MockKeyboardController(beforeInput: "teh")
        handler.controller = controller

        handler.insertText(" ")

        #expect(controller.mockProxy.documentContextBeforeInput == "teh ")
    }

    @Test func testWordLearnsAfterSecondCorrectionRevert() async throws {
        let service = makeIsolatedService()
        let handler = KeyboardActionHandler(personalDictionaryService: service)

        let firstController = MockKeyboardController(beforeInput: "teh")
        handler.controller = firstController
        handler.insertText(" ")
        handler.deleteBackward()
        #expect(service.containsLearnedWord("teh") == false)
        #expect(service.revertCount(for: "teh") == 0)

        handler.insertText(" ")
        #expect(firstController.mockProxy.documentContextBeforeInput == "teh ")
        #expect(service.revertCount(for: "teh") == 1)

        let secondController = MockKeyboardController(beforeInput: "teh")
        handler.controller = secondController
        handler.insertText(" ")
        handler.deleteBackward()
        #expect(service.containsLearnedWord("teh") == false)
        #expect(service.revertCount(for: "teh") == 1)

        handler.insertText(" ")

        #expect(service.containsLearnedWord("teh"))
        #expect(service.revertCount(for: "teh") == 0)
    }

    @Test func testImmediateSpaceAfterRevertKeepsOriginalWordAndCountsLearning() async throws {
        let service = makeIsolatedService()
        let handler = KeyboardActionHandler(personalDictionaryService: service)
        let controller = MockKeyboardController(beforeInput: "teh")
        handler.controller = controller

        handler.insertText(" ")
        #expect(controller.mockProxy.documentContextBeforeInput == "the ")

        handler.deleteBackward()
        #expect(controller.mockProxy.documentContextBeforeInput == "teh")
        #expect(service.revertCount(for: "teh") == 0)

        handler.insertText(" ")
        #expect(controller.mockProxy.documentContextBeforeInput == "teh ")
        #expect(service.revertCount(for: "teh") == 1)
        #expect(service.containsLearnedWord("teh") == false)
    }

    @Test func testEditingAfterRevertCancelsLearningCandidate() async throws {
        let service = makeIsolatedService()
        let handler = KeyboardActionHandler(personalDictionaryService: service)
        let controller = MockKeyboardController(beforeInput: "teh")
        handler.controller = controller

        handler.insertText(" ")
        handler.deleteBackward()
        #expect(controller.mockProxy.documentContextBeforeInput == "teh")
        #expect(service.revertCount(for: "teh") == 0)

        handler.insertText("n")

        #expect(controller.mockProxy.documentContextBeforeInput == "tehn")
        #expect(service.revertCount(for: "teh") == 0)
        #expect(service.containsLearnedWord("teh") == false)
    }
}

private func makeIsolatedService() -> PersonalDictionaryService {
    let suiteName = "test.personal-dictionary.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    return PersonalDictionaryService(defaults: defaults)
}

private final class MockKeyboardController: UIInputViewController {
    let mockProxy: MockTextDocumentProxy

    init(beforeInput: String = "", afterInput: String = "") {
        self.mockProxy = MockTextDocumentProxy(beforeInput: beforeInput, afterInput: afterInput)
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var textDocumentProxy: UITextDocumentProxy {
        mockProxy
    }
}

private final class MockTextDocumentProxy: NSObject, UITextDocumentProxy {
    var documentContextBeforeInput: String?
    var documentContextAfterInput: String?
    var selectedText: String?
    var documentInputMode: UITextInputMode?
    var documentIdentifier: UUID

    init(beforeInput: String = "", afterInput: String = "") {
        self.documentContextBeforeInput = beforeInput
        self.documentContextAfterInput = afterInput
        self.documentIdentifier = UUID()
    }

    var hasText: Bool {
        !(documentContextBeforeInput ?? "").isEmpty || !(documentContextAfterInput ?? "").isEmpty
    }

    func insertText(_ text: String) {
        documentContextBeforeInput = (documentContextBeforeInput ?? "") + text
    }

    func deleteBackward() {
        guard var before = documentContextBeforeInput, !before.isEmpty else { return }
        before.removeLast()
        documentContextBeforeInput = before
    }

    func adjustTextPosition(byCharacterOffset offset: Int) {
        guard offset != 0 else { return }

        if offset < 0 {
            for _ in 0..<abs(offset) {
                guard var before = documentContextBeforeInput, let moved = before.popLast() else { break }
                documentContextBeforeInput = before
                documentContextAfterInput = String(moved) + (documentContextAfterInput ?? "")
            }
        } else {
            for _ in 0..<offset {
                guard var after = documentContextAfterInput, !after.isEmpty else { break }
                let moved = after.removeFirst()
                documentContextAfterInput = after
                documentContextBeforeInput = (documentContextBeforeInput ?? "") + String(moved)
            }
        }
    }

    func setMarkedText(_ markedText: String, selectedRange: NSRange) {}
    func unmarkText() {}
}
