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
    @Published var isCapsLocked: Bool = false
    @Published var currentKeyboardType: KeyboardType = .alphabetic
    private var lastSpacePressTime: Date?
    private var lastShiftPressTime: Date?
    
    // MARK: - Contraction Map
    private let contractionMap: [String: String] = [
        "dont"     : "don't",
        "cant"     : "can't",
        "wont"     : "won't",
        "isnt"     : "isn't",
        "arent"    : "aren't",
        "wasnt"    : "wasn't",
        "didnt"    : "didn't",
        "doesnt"   : "doesn't",
        "havent"   : "haven't",
        "wouldnt"  : "wouldn't",
        "shouldnt" : "shouldn't",
        "couldnt"  : "couldn't",
        "youre"    : "you're",
        "theyre"   : "they're",
        "weve"     : "we've",
        "thats"    : "that's",
        "whats"    : "what's",
        "hes"      : "he's",
        "shes"     : "she's",
        "im"       : "I'm",
        "ive"      : "I've",
    ]
    
    // Pure function: checks if the last word in context is an uncorrected contraction.
    // Returns (charsToDelete, correctedWord) if a match is found.
    func evaluateContraction(context: String) -> (charsToDelete: Int, corrected: String)? {
        // Extract last word (stop at whitespace/newline)
        var lastWord = ""
        for char in context.reversed() {
            guard char != " ", char != "\n" else { break }
            lastWord = String(char) + lastWord
        }
        guard !lastWord.isEmpty else { return nil }
        
        let lower = lastWord.lowercased()
        guard let corrected = contractionMap[lower] else { return nil }
        
        // Preserve leading capital if user typed e.g. "Dont" → "Don't"
        let isCapitalized = lastWord.first?.isUppercase == true
        let finalCorrected = isCapitalized
            ? corrected.prefix(1).uppercased() + corrected.dropFirst()
            : corrected
        
        return (charsToDelete: lastWord.count, corrected: finalCorrected)
    }
    
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
        
        // On space: check for contraction correction BEFORE double-space-to-period logic
        if text == " ", let ctx = context, let fix = evaluateContraction(context: ctx) {
            for _ in 0..<fix.charsToDelete {
                controller?.textDocumentProxy.deleteBackward()
            }
            controller?.textDocumentProxy.insertText(fix.corrected + " ")
            evaluateAutoCapitalization(contextBefore: ctx + fix.corrected + " ")
            lastSpacePressTime = nil // Reset double-space timer after correction
            return
        }
        
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
        guard controller?.textDocumentProxy.hasText == true else { return }
        controller?.textDocumentProxy.deleteBackward()
        HapticFeedback.playLight()
        
        // Also manually evaluate on deletion using the proxy (which updates slightly faster on delete, but we should force a check)
        // Note: For deletion, context might still lag, but a slight delay is standard.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            let context = self.controller?.textDocumentProxy.documentContextBeforeInput
            self.evaluateAutoCapitalization(contextBefore: context)
        }
    }
    
    // Pure function: counts how many characters to delete to remove the last word + trailing whitespace.
    // Extracted for full unit testability.
    func charsToDeleteForWordBackward(context: String) -> Int {
        guard !context.isEmpty else { return 0 }
        
        if context.last == "\n" { return 1 }
        
        var count = 0
        var hitNonWhitespace = false
        
        for char in context.reversed() {
            let isWhitespace = char == " " || char == "\n"
            if isWhitespace {
                // Consume leading whitespace before the word, then stop once we hit the word
                if hitNonWhitespace { break }
            } else {
                hitNonWhitespace = true
            }
            count += 1
        }
        return count
    }
    
    func deleteWordBackward() {
        guard let context = controller?.textDocumentProxy.documentContextBeforeInput,
              !context.isEmpty else { return }
        
        let count = charsToDeleteForWordBackward(context: context)
        for _ in 0..<count {
            controller?.textDocumentProxy.deleteBackward()
        }
        HapticFeedback.playMedium() // Stronger haptic to signal word-level deletion
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            let ctx = self.controller?.textDocumentProxy.documentContextBeforeInput
            self.evaluateAutoCapitalization(contextBefore: ctx)
        }
    }
    
    // MARK: - Dedicated Input Handlers
    
    func typeLetter(_ letter: String) {
        insertText(letter)
        if !isCapsLocked {
            // Turn off manual shift after a regular letter is typed, unless we are caps locked
            isShiftEnabled = false
        }
    }
    
    func handleShiftPress() {
        let now = Date()
        if let last = lastShiftPressTime, now.timeIntervalSince(last) < 0.35 {
            // Double tap!
            isCapsLocked = true
            isShiftEnabled = true
        } else {
            // Normal tap
            isCapsLocked = false
            isShiftEnabled.toggle()
        }
        lastShiftPressTime = now
    }
    
    func evaluateAutoCapitalization(contextBefore: String?) {
        if isCapsLocked { return } // Aggressively bypass auto-evaluation if mechanically locked!
        
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
