import Testing
import Foundation
@testable import MyCuKey

@MainActor
struct CapsLockTests {
    
    @Test func testSingleShiftTapTogglesShift() async throws {
        let handler = KeyboardActionHandler()
        handler.isShiftEnabled = false
        handler.handleShiftPress()
        #expect(handler.isShiftEnabled == true, "A single shift press should enable shift.")
        #expect(handler.isCapsLocked == false, "A single shift press must NOT enable Caps Lock.")
    }
    
    @Test func testDoubleShiftTapEnablesCapsLock() async throws {
        let handler = KeyboardActionHandler()
        handler.handleShiftPress()
        handler.handleShiftPress() // Two sequential calls always land within 0.35s
        #expect(handler.isCapsLocked == true, "Double-tapping shift quickly must lock Caps Lock ON.")
        #expect(handler.isShiftEnabled == true, "Caps Lock must keep shift visually enabled.")
    }
    
    @Test func testTypeLetterDoesNotDisableShiftWhenCapsLocked() async throws {
        let handler = KeyboardActionHandler()
        handler.isCapsLocked = true
        handler.isShiftEnabled = true
        handler.typeLetter("A")
        #expect(handler.isShiftEnabled == true, "Typing a letter must NOT disable shift when Caps Lock is engaged.")
    }
    
    @Test func testTypeLetterDisablesShiftWhenNotCapsLocked() async throws {
        let handler = KeyboardActionHandler()
        handler.isCapsLocked = false
        handler.isShiftEnabled = true
        handler.typeLetter("a")
        #expect(handler.isShiftEnabled == false, "Typing a letter must disable shift when Caps Lock is OFF.")
    }
    
    @Test func testAutoCapitalizationBypassedWhenCapsLocked() async throws {
        let handler = KeyboardActionHandler()
        handler.isCapsLocked = true
        handler.isShiftEnabled = true
        handler.evaluateAutoCapitalization(contextBefore: "Hello world")
        #expect(handler.isShiftEnabled == true, "evaluateAutoCapitalization must be a no-op when Caps Lock is engaged.")
    }
}
