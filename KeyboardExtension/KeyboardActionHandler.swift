import UIKit
import Combine

// MARK: - Keyboard Types
enum KeyboardType {
    case alphabetic
    case numeric
    case symbolic
}

// MARK: - Keyboard Action Handler
class KeyboardActionHandler: ObservableObject {
    weak var controller: UIInputViewController?
    @Published var isShiftEnabled: Bool = false
    @Published var currentKeyboardType: KeyboardType = .alphabetic
    private var lastSpacePressTime: Date?
    
    // Pure function extracting the double-space logic, making it fully unit-testable!
    func evaluateTextInsertion(text: String, context: String?, now: Date, lastPress: Date?) -> (textToInsert: String, needsDeleteBackward: Bool, newLastSpacePress: Date?) {
        if text == " " {
            // Check if space was pressed within the last 0.25 seconds for a snappier feel
            if let maxDelay = lastPress, now.timeIntervalSince(maxDelay) < 0.25 {
                let safeContext = context ?? ""
                
                // Ensure there is exactly one space before we delete and add period
                if safeContext.hasSuffix(" ") && !safeContext.hasSuffix("  ") {
                    return (textToInsert: ". ", needsDeleteBackward: true, newLastSpacePress: nil)
                }
            }
            return (textToInsert: " ", needsDeleteBackward: false, newLastSpacePress: now)
        }
        
        // Reset timer if any other key is pressed
        return (textToInsert: text, needsDeleteBackward: false, newLastSpacePress: nil)
    }

    func insertText(_ text: String) {
        let context = controller?.textDocumentProxy.documentContextBeforeInput
        let result = evaluateTextInsertion(text: text, context: context, now: Date(), lastPress: lastSpacePressTime)
        
        lastSpacePressTime = result.newLastSpacePress
        
        if result.needsDeleteBackward {
            controller?.textDocumentProxy.deleteBackward()
        }
        controller?.textDocumentProxy.insertText(result.textToInsert)
        
        // **SYNCHRONOUS PREDICTION FIX**
        // The iOS textDocumentProxy lags slightly behind inserts during the IPC bridge delay.
        // We MUST manually calculate the resulting context string to check auto-capitalization exactly when the key is hit!
        let originalContext = context ?? ""
        let newContext = result.needsDeleteBackward ? String(originalContext.dropLast()) + result.textToInsert : originalContext + result.textToInsert
        evaluateAutoCapitalization(contextBefore: newContext)
    }
    
    func deleteBackward() {
        controller?.textDocumentProxy.deleteBackward()
        
        // Also manually evaluate on deletion using the proxy (which updates slightly faster on delete, but we should force a check)
        // Note: For deletion, context might still lag, but a slight delay is standard.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            let context = self.controller?.textDocumentProxy.documentContextBeforeInput
            self.evaluateAutoCapitalization(contextBefore: context)
        }
    }
    
    func evaluateAutoCapitalization(contextBefore: String?) {
        let text = contextBefore ?? ""
        if text.isEmpty {
            self.isShiftEnabled = true
            return
        }
        
        let triggerEndings = [
            // Standard sentence terminators (with and without space)
            ".", ". ",
            "!", "! ",
            "?", "? ",
            "\n",
            
            // Custom asterisk rules
            "\n*", "\n* ", // New line + *
            ".*", ".* ",   // Dot + *
            ". *", ". * "  // Dot + space + *
        ]
        
        // Disable shift unless it explicitly hits a trigger terminating token
        self.isShiftEnabled = false
        for ending in triggerEndings {
            if text.hasSuffix(ending) {
                self.isShiftEnabled = true
                break
            }
        }
    }
}
