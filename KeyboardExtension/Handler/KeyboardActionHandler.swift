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
    
    let contractionEngine = ContractionEngine()
    let autocorrectionEngine = AutocorrectionEngine()
    let correctionTriggerInputs: Set<String> = [" ", ".", ",", "!", "?", "*", "\n"]
    
    // MARK: - Text Insertion
    
    // Pure function: double-space-to-period logic. Fully unit-testable.
    func evaluateTextInsertion(text: String, context: String?, now: Date, lastPress: Date?) -> (textToInsert: String, needsDeleteBackward: Bool, newLastSpacePress: Date?) {
        if text == " " {
            if let maxDelay = lastPress, now.timeIntervalSince(maxDelay) < 0.25 {
                let safeContext = context ?? ""
                if safeContext.hasSuffix(" ") && !safeContext.hasSuffix("  ") {
                    return (textToInsert: ". ", needsDeleteBackward: true, newLastSpacePress: nil)
                }
            }
            return (textToInsert: " ", needsDeleteBackward: false, newLastSpacePress: now)
        }
        return (textToInsert: text, needsDeleteBackward: false, newLastSpacePress: nil)
    }

    func insertText(_ text: String) {
        let context = controller?.textDocumentProxy.documentContextBeforeInput
        let correctionSuffix = correctionSuffix(for: text)
        
        // Priority 1: contraction correction (dont → don't)
        if let suffix = correctionSuffix, let ctx = context, let fix = contractionEngine.evaluate(context: ctx) {
            applyReplacement(fix, originalContext: ctx, trailingInput: suffix)
            return
        }
        
        // Priority 2: lightweight autocorrection (single-typo UITextChecker)
        if let suffix = correctionSuffix, let ctx = context, let fix = autocorrectionEngine.evaluate(context: ctx) {
            applyReplacement(fix, originalContext: ctx, trailingInput: suffix)
            return
        }
        
        // Priority 3: double-space → period
        let result = evaluateTextInsertion(text: text, context: context, now: Date(), lastPress: lastSpacePressTime)
        lastSpacePressTime = result.newLastSpacePress
        
        if result.needsDeleteBackward {
            controller?.textDocumentProxy.deleteBackward()
        }
        controller?.textDocumentProxy.insertText(result.textToInsert)
        
        // Synchronous prediction fix — proxy lags on IPC, so calculate context manually
        let originalContext = context ?? ""
        let newContext = result.needsDeleteBackward
            ? String(originalContext.dropLast()) + result.textToInsert
            : originalContext + result.textToInsert
        evaluateAutoCapitalization(contextBefore: newContext)
    }
    
    // Shared replacement apply — uses Diff logic to minimize flicker.
    // Instead of deleting the whole word, it only deletes the suffix that changed.
    private func applyReplacement(_ fix: (charsToDelete: Int, corrected: String), originalContext: String, trailingInput: String) {
        let oldWord = String(originalContext.suffix(fix.charsToDelete))
        let newWord = fix.corrected
        
        let prefixLen = commonPrefixLength(oldWord, newWord)
        
        // Number of characters to delete (the part of the old word that doesn't match the new word)
        let deleteCount = oldWord.count - prefixLen
        
        // Part of the new word that needs to be inserted + trailing input (" ", ".", "!", etc.)
        let insertSuffix = String(newWord.dropFirst(prefixLen)) + trailingInput
        
        for _ in 0..<deleteCount {
            controller?.textDocumentProxy.deleteBackward()
        }
        
        controller?.textDocumentProxy.insertText(insertSuffix)
        
        evaluateAutoCapitalization(contextBefore: originalContext + fix.corrected + trailingInput)
        lastSpacePressTime = nil
    }

    func correctionSuffix(for input: String) -> String? {
        correctionTriggerInputs.contains(input) ? input : nil
    }
    
    private func commonPrefixLength(_ a: String, _ b: String) -> Int {
        let aChars = Array(a)
        let bChars = Array(b)
        var i = 0
        while i < aChars.count && i < bChars.count && aChars[i] == bChars[i] {
            i += 1
        }
        return i
    }
    
    // MARK: - Delete
    
    func deleteBackward() {
        guard controller?.textDocumentProxy.hasText == true else { return }
        controller?.textDocumentProxy.deleteBackward()
        HapticFeedback.playLight()

        refreshAutoCapitalizationAfterDelete()
    }
    
    // Pure function: counts chars to delete to remove the last word + trailing whitespace.
    func charsToDeleteForWordBackward(context: String) -> Int {
        guard !context.isEmpty else { return 0 }
        if context.last == "\n" { return 1 }
        
        var count = 0
        var hitNonWhitespace = false
        
        for char in context.reversed() {
            let isWhitespace = char == " " || char == "\n"
            if isWhitespace {
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
        HapticFeedback.playMedium()

        refreshAutoCapitalizationAfterDelete()
    }
    
    // MARK: - Shift & Caps Lock
    
    func typeLetter(_ letter: String) {
        insertText(letter)
        if !isCapsLocked {
            isShiftEnabled = false
        }
    }
    
    func handleShiftPress() {
        let now = Date()
        if let last = lastShiftPressTime, now.timeIntervalSince(last) < 0.35 {
            isCapsLocked = true
            isShiftEnabled = true
        } else {
            isCapsLocked = false
            isShiftEnabled.toggle()
        }
        lastShiftPressTime = now
    }
    
    // MARK: - Auto-Capitalization
    
    func evaluateAutoCapitalization(contextBefore: String?) {
        if isCapsLocked { return }
        
        let text = contextBefore ?? ""
        if text.isEmpty {
            self.isShiftEnabled = true
            return
        }
        
        let triggerEndings = [
            ".", ". ",
            "!", "! ",
            "?", "? ",
            "\n",
            "\n*", "\n* ",
            ".*", ".* ",
            ". *", ". * "
        ]
        
        self.isShiftEnabled = false
        for ending in triggerEndings {
            if text.hasSuffix(ending) {
                self.isShiftEnabled = true
                break
            }
        }
    }

    private func refreshAutoCapitalizationAfterDelete() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            let context = self.controller?.textDocumentProxy.documentContextBeforeInput
            self.evaluateAutoCapitalization(contextBefore: context)
        }
    }
}
