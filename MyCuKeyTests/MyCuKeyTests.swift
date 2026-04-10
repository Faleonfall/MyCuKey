import Testing
import Foundation
@testable import MyCuKey

@MainActor
struct MyCuKeyTests {

    @Test func testKeyboardCapitalizationAtStart() async throws {
        let handler = KeyboardActionHandler()
        handler.isShiftEnabled = false
        
        // Simulating loading into a completely empty text field
        handler.evaluateAutoCapitalization(contextBefore: "")
        
        #expect(handler.isShiftEnabled == true, "Keyboard should automatically shift on empty fields.")
    }
    
    @Test func testKeyboardCapitalizationAfterSentence() async throws {
        let handler = KeyboardActionHandler()
        handler.isShiftEnabled = false
        
        // Simulating typing the end of a sentence
        handler.evaluateAutoCapitalization(contextBefore: "Hello world. ")
        
        #expect(handler.isShiftEnabled == true, "Keyboard should automatically shift after a period and space.")
    }
    
    @Test func testKeyboardNoCapitalizationMidSentence() async throws {
        let handler = KeyboardActionHandler()
        handler.isShiftEnabled = false
        
        // Simulating standard typing
        handler.evaluateAutoCapitalization(contextBefore: "Hello wo")
        
        #expect(handler.isShiftEnabled == false, "Keyboard should not shift in the middle of a word.")
    }

    @Test func testDoubleSpaceIsReplacedWithDot() async throws {
        let handler = KeyboardActionHandler()
        let time1 = Date()
        let time2 = time1.addingTimeInterval(0.2) // 0.2 seconds later (fast double tap)
        
        // First, check that a single space acts normally
        let firstPress = handler.evaluateTextInsertion(text: " ", context: "Hello", now: time1, lastPress: nil)
        #expect(firstPress.textToInsert == " ", "First space should insert normally.")
        #expect(firstPress.needsDeleteBackward == false, "First space shouldn't delete backward.")
        
        // Next, simulate the second fast space!
        let secondPress = handler.evaluateTextInsertion(text: " ", context: "Hello ", now: time2, lastPress: firstPress.newLastSpacePress)
        #expect(secondPress.textToInsert == ". ", "Fast double space should insert a period and space.")
        #expect(secondPress.needsDeleteBackward == true, "Double space must delete the FIRST space backward.")
        #expect(secondPress.newLastSpacePress == nil, "Press timer must reset after a period is placed.")
    }
    
    @Test func testSlowDoubleSpaceIsIgnored() async throws {
        let handler = KeyboardActionHandler()
        let time1 = Date()
        let time2 = time1.addingTimeInterval(1.5) // 1.5 seconds later (too slow!)
        
        let firstPress = handler.evaluateTextInsertion(text: " ", context: "Hello", now: time1, lastPress: nil)
        
        // Next, simulate the second SLOW space
        let secondPress = handler.evaluateTextInsertion(text: " ", context: "Hello ", now: time2, lastPress: firstPress.newLastSpacePress)
        #expect(secondPress.textToInsert == " ", "Slow double space should just insert another normal space.")
        #expect(secondPress.needsDeleteBackward == false, "Slow space should NOT delete anything.")
        #expect(secondPress.newLastSpacePress == time2, "Timer should reset to this new slow press.")
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
        let time2 = time1.addingTimeInterval(0.1) // insanely fast typing!
        
        // 1. Tap 'Space'
        let firstPress = handler.evaluateTextInsertion(text: " ", context: "Hello", now: time1, lastPress: nil)
        
        // 2. Tap 'A' instead of space
        let intermediatePress = handler.evaluateTextInsertion(text: "A", context: "Hello ", now: time2, lastPress: firstPress.newLastSpacePress)
        
        #expect(intermediatePress.textToInsert == "A", "Normal key inserts correctly.")
        #expect(intermediatePress.newLastSpacePress == nil, "Typing any other letter MUST instantly wipe the double-space timer memory.")
    }

}
