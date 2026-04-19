import Testing
import Foundation
@testable import MyCuKey

// MARK: - Keyboard Core Tests

// Core tests: auto-capitalization, double-space, keyboard type state
@MainActor
struct MyCuKeyTests {

    // MARK: - Auto-Capitalization

    @Test func testKeyboardCapitalizationAtStart() async throws {
        let handler = KeyboardActionHandler()
        handler.isShiftEnabled = false
        handler.evaluateAutoCapitalization(contextBefore: "")
        #expect(handler.isShiftEnabled == true, "Keyboard should automatically shift on empty fields.")
    }
    
    @Test func testKeyboardCapitalizationAfterSentence() async throws {
        let handler = KeyboardActionHandler()
        handler.isShiftEnabled = false
        handler.evaluateAutoCapitalization(contextBefore: "Hello world. ")
        #expect(handler.isShiftEnabled == true, "Keyboard should automatically shift after a period and space.")
    }
    
    @Test func testKeyboardNoCapitalizationMidSentence() async throws {
        let handler = KeyboardActionHandler()
        handler.isShiftEnabled = false
        handler.evaluateAutoCapitalization(contextBefore: "Hello wo")
        #expect(handler.isShiftEnabled == false, "Keyboard should not shift in the middle of a word.")
    }

    @Test func testDoubleSpaceIsReplacedWithDot() async throws {
        let handler = KeyboardActionHandler()
        let time1 = Date()
        let time2 = time1.addingTimeInterval(0.2)
        
        let firstPress = handler.evaluateTextInsertion(text: " ", context: "Hello", now: time1, lastPress: nil)
        #expect(firstPress.textToInsert == " ", "First space should insert normally.")
        #expect(firstPress.needsDeleteBackward == false)
        
        let secondPress = handler.evaluateTextInsertion(text: " ", context: "Hello ", now: time2, lastPress: firstPress.newLastSpacePress)
        #expect(secondPress.textToInsert == ". ", "Fast double space should insert a period and space.")
        #expect(secondPress.needsDeleteBackward == true)
        #expect(secondPress.newLastSpacePress == nil, "Press timer must reset after a period is placed.")
    }
    
    @Test func testSlowDoubleSpaceIsIgnored() async throws {
        let handler = KeyboardActionHandler()
        let time1 = Date()
        let time2 = time1.addingTimeInterval(1.5)
        
        let firstPress = handler.evaluateTextInsertion(text: " ", context: "Hello", now: time1, lastPress: nil)
        let secondPress = handler.evaluateTextInsertion(text: " ", context: "Hello ", now: time2, lastPress: firstPress.newLastSpacePress)
        #expect(secondPress.textToInsert == " ", "Slow double space should just insert another normal space.")
        #expect(secondPress.needsDeleteBackward == false)
        #expect(secondPress.newLastSpacePress == time2, "Timer should reset to this new slow press.")
    }

    // MARK: - Double-Space Period

    @Test func testDoubleSpaceBoundaryAtExactlyPoint25SecondsIsIgnored() async throws {
        let handler = KeyboardActionHandler()
        let time1 = Date()
        let time2 = time1.addingTimeInterval(0.25)

        let firstPress = handler.evaluateTextInsertion(text: " ", context: "Hello", now: time1, lastPress: nil)
        let secondPress = handler.evaluateTextInsertion(text: " ", context: "Hello ", now: time2, lastPress: firstPress.newLastSpacePress)
        #expect(secondPress.textToInsert == " ", "At exactly 0.25s, replacement should not trigger because threshold is strict (< 0.25).")
        #expect(secondPress.needsDeleteBackward == false)
    }

    @Test func testDoubleSpaceBoundaryJustBelowPoint25SecondsTriggersPeriod() async throws {
        let handler = KeyboardActionHandler()
        let time1 = Date()
        let time2 = time1.addingTimeInterval(0.249)

        let firstPress = handler.evaluateTextInsertion(text: " ", context: "Hello", now: time1, lastPress: nil)
        let secondPress = handler.evaluateTextInsertion(text: " ", context: "Hello ", now: time2, lastPress: firstPress.newLastSpacePress)
        #expect(secondPress.textToInsert == ". ")
        #expect(secondPress.needsDeleteBackward == true)
    }

    @Test func testDoubleSpaceDoesNotTriggerAfterTwoSpacesAlreadyPresent() async throws {
        let handler = KeyboardActionHandler()
        let time1 = Date()
        let time2 = time1.addingTimeInterval(0.1)

        let firstPress = handler.evaluateTextInsertion(text: " ", context: "Hello ", now: time1, lastPress: nil)
        let secondPress = handler.evaluateTextInsertion(text: " ", context: "Hello  ", now: time2, lastPress: firstPress.newLastSpacePress)
        #expect(secondPress.textToInsert == " ")
        #expect(secondPress.needsDeleteBackward == false)
    }

    @Test func testKeyboardCapitalizationAfterExclamationAndQuestionMark() async throws {
        let handler = KeyboardActionHandler()
        
        handler.isShiftEnabled = false
        handler.evaluateAutoCapitalization(contextBefore: "Wow! ")
        #expect(handler.isShiftEnabled == true, "Keyboard should shift after exclamation mark and space.")
        
        handler.isShiftEnabled = false
        handler.evaluateAutoCapitalization(contextBefore: "Really? ")
        #expect(handler.isShiftEnabled == true, "Keyboard should shift after question mark and space.")
    }
    
    @Test func testKeyboardCapitalizationAfterNewLine() async throws {
        let handler = KeyboardActionHandler()
        handler.isShiftEnabled = false
        handler.evaluateAutoCapitalization(contextBefore: "Line one\n")
        #expect(handler.isShiftEnabled == true, "Keyboard should shift after a carriage return.")
    }

    @Test func testSpaceTapTimerResetByOtherKey() async throws {
        let handler = KeyboardActionHandler()
        let time1 = Date()
        let time2 = time1.addingTimeInterval(0.1)
        
        let firstPress = handler.evaluateTextInsertion(text: " ", context: "Hello", now: time1, lastPress: nil)
        let intermediatePress = handler.evaluateTextInsertion(text: "A", context: "Hello ", now: time2, lastPress: firstPress.newLastSpacePress)
        
        #expect(intermediatePress.textToInsert == "A")
        #expect(intermediatePress.newLastSpacePress == nil, "Typing any other letter must wipe the double-space timer.")
    }

    @Test func testKeyboardTypeInitializesToAlphabetic() async throws {
        let handler = KeyboardActionHandler()
        #expect(handler.currentKeyboardType == .alphabetic)
    }

    @Test func testKeyboardTypeCanBeToggledToNumericAndSymbolic() async throws {
        let handler = KeyboardActionHandler()
        handler.currentKeyboardType = .numeric
        #expect(handler.currentKeyboardType == .numeric)
        handler.currentKeyboardType = .symbolic
        #expect(handler.currentKeyboardType == .symbolic)
    }

    // MARK: - Additional Capitalization Context

    @Test func testKeyboardCapitalizationWithAsterisksAndSpacelessTerminators() async throws {
        let handler = KeyboardActionHandler()
        
        handler.evaluateAutoCapitalization(contextBefore: "Hello world.")
        #expect(handler.isShiftEnabled == true, "Must shift after a raw dot without a space.")
        
        handler.evaluateAutoCapitalization(contextBefore: "Line one\n*")
        #expect(handler.isShiftEnabled == true, "Must shift after bullet points.")
        
        handler.evaluateAutoCapitalization(contextBefore: "Hello.*")
        #expect(handler.isShiftEnabled == true, "Must shift after dot followed by asterisk.")
        
        handler.evaluateAutoCapitalization(contextBefore: "Hello. *")
        #expect(handler.isShiftEnabled == true, "Must shift after dot, space, asterisk combination.")
        
        handler.evaluateAutoCapitalization(contextBefore: "Hello *")
        #expect(handler.isShiftEnabled == false, "Must NOT shift after a raw asterisk unconnected to punctuation.")
    }

    @Test func testKeyboardCapitalizationAfterBulletPrefixOnCurrentLine() async throws {
        let handler = KeyboardActionHandler()

        handler.evaluateAutoCapitalization(contextBefore: "*")
        #expect(handler.isShiftEnabled == true, "Must shift when a bullet asterisk is the whole current line.")

        handler.evaluateAutoCapitalization(contextBefore: "* ")
        #expect(handler.isShiftEnabled == true, "Must keep shift enabled after bullet asterisk followed by a space.")

        handler.evaluateAutoCapitalization(contextBefore: "Line one\n*")
        #expect(handler.isShiftEnabled == true, "Must shift when a bullet asterisk starts a new line.")

        handler.evaluateAutoCapitalization(contextBefore: "Line one\n* ")
        #expect(handler.isShiftEnabled == true, "Must keep shift enabled after a bullet asterisk and space on a new line.")
    }
    
    @Test func testKeyboardCapitalizationDisablesAfterTypingNormalLetters() async throws {
        let handler = KeyboardActionHandler()
        handler.isShiftEnabled = true
        handler.evaluateAutoCapitalization(contextBefore: "Hello world")
        #expect(handler.isShiftEnabled == false, "Typing normal letters must un-shift the keyboard.")
    }
    
    @Test func testKeyboardCapitalizationWithMultiplePunctuationMarks() async throws {
        let handler = KeyboardActionHandler()
        
        handler.evaluateAutoCapitalization(contextBefore: "Wait...")
        #expect(handler.isShiftEnabled == true, "Multiple dots ending in a trigger should capitalize.")
        
        handler.evaluateAutoCapitalization(contextBefore: "Really?!")
        #expect(handler.isShiftEnabled == true, "Compound punctuation should recognize the exclamation mark.")
    }

    @Test func testCorrectionSuffixIncludesPunctuationTriggers() async throws {
        let handler = KeyboardActionHandler()
        #expect(handler.correctionSuffix(for: " ") == " ")
        #expect(handler.correctionSuffix(for: ".") == ".")
        #expect(handler.correctionSuffix(for: ",") == ",")
        #expect(handler.correctionSuffix(for: "!") == "!")
        #expect(handler.correctionSuffix(for: "?") == "?")
        #expect(handler.correctionSuffix(for: "*") == "*")
        #expect(handler.correctionSuffix(for: "\n") == "\n")
    }

    @Test func testCorrectionSuffixSkipsRegularLetters() async throws {
        let handler = KeyboardActionHandler()
        #expect(handler.correctionSuffix(for: "a") == nil)
        #expect(handler.correctionSuffix(for: "Z") == nil)
        #expect(handler.correctionSuffix(for: "1") == nil)
    }
}
