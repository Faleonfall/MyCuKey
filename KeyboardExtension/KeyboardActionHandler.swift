import UIKit
import Combine

// MARK: - Keyboard Action Handler
class KeyboardActionHandler: ObservableObject {
    weak var controller: UIInputViewController?
    @Published var isShiftEnabled: Bool = false
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
    }
    
    func deleteBackward() {
        controller?.textDocumentProxy.deleteBackward()
    }
    
    func evaluateAutoCapitalization(contextBefore: String?) {
        let text = contextBefore ?? ""
        if text.isEmpty {
            self.isShiftEnabled = true
        } else if text.hasSuffix(". ") || text.hasSuffix("! ") || text.hasSuffix("? ") || text.hasSuffix("\n") {
            self.isShiftEnabled = true
        }
    }
}
