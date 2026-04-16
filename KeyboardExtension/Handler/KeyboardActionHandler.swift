import UIKit
import Combine

// MARK: - Keyboard Types
enum KeyboardType {
    case alphabetic
    case numeric
    case symbolic
}

struct PendingCorrectionRevert {
    let originalWord: String
    let correctedWord: String
    let trailingInput: String
}

struct PendingDictionaryLearningCandidate {
    let originalWord: String
    let restoredContextSuffix: String

    var confirmedByTriggerInput: Bool {
        true
    }
}

// MARK: - Keyboard Action Handler
class KeyboardActionHandler: ObservableObject {
    weak var controller: UIInputViewController?
    @Published var isShiftEnabled: Bool = false
    @Published var isCapsLocked: Bool = false
    @Published var currentKeyboardType: KeyboardType = .alphabetic
    private var lastSpacePressTime: Date?
    private var lastShiftPressTime: Date?
    private var pendingCorrectionRevert: PendingCorrectionRevert?
    private var pendingDictionaryLearningCandidate: PendingDictionaryLearningCandidate?
    private let personalDictionaryService: PersonalDictionaryService
    
    let contractionEngine = ContractionEngine()
    let autocorrectionEngine = AutocorrectionEngine()
    let correctionTriggerInputs: Set<String> = [" ", ".", ",", "!", "?", "*", "\n"]

    init(personalDictionaryService: PersonalDictionaryService) {
        self.personalDictionaryService = personalDictionaryService
        self.personalDictionaryService.refreshFromStorage()
    }

    convenience init() {
        self.init(personalDictionaryService: .shared)
    }
    
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
        clearPendingCorrectionIfNeeded(for: text)
        let confirmedPendingLearning = processPendingDictionaryLearningIfNeeded(forNextInput: text)
        let context = controller?.textDocumentProxy.documentContextBeforeInput
        let correctionSuffix = correctionSuffix(for: text)
        if correctionSuffix != nil {
            personalDictionaryService.refreshFromStorage()
        }
        let shouldSkipCorrections = confirmedPendingLearning || (context.map { shouldSuppressCorrections(for: $0) } ?? false)

        if let ctx = context, let standaloneIReplacement = standaloneLowercaseIReplacement(context: ctx, trailingInput: text) {
            applyReplacement(standaloneIReplacement, originalContext: ctx, trailingInput: text)
            return
        }
        
        // Priority 1: contraction correction (dont → don't)
        if !shouldSkipCorrections, let suffix = correctionSuffix, let ctx = context, let fix = contractionEngine.evaluate(context: ctx) {
            applyReplacement(fix, originalContext: ctx, trailingInput: suffix)
            return
        }
        
        // Priority 2: lightweight autocorrection (single-typo UITextChecker)
        if !shouldSkipCorrections, let suffix = correctionSuffix, let ctx = context, let fix = autocorrectionEngine.evaluate(context: ctx) {
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
    private func applyReplacement(_ fix: AutocorrectionResult, originalContext: String, trailingInput: String) {
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
        pendingCorrectionRevert = PendingCorrectionRevert(
            originalWord: oldWord,
            correctedWord: newWord,
            trailingInput: trailingInput
        )
        HapticFeedback.playSoft()
        
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
        if revertLastCorrectionIfPossible() {
            HapticFeedback.playRigid()
            refreshAutoCapitalizationAfterDelete()
            return
        }

        guard controller?.textDocumentProxy.hasText == true else { return }
        pendingDictionaryLearningCandidate = nil
        controller?.textDocumentProxy.deleteBackward()
        pendingCorrectionRevert = nil
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
        
        pendingDictionaryLearningCandidate = nil
        pendingCorrectionRevert = nil
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

    private func clearPendingCorrectionIfNeeded(for input: String) {
        if pendingCorrectionRevert == nil {
            return
        }

        if correctionSuffix(for: input) == nil {
            pendingCorrectionRevert = nil
        }
    }

    private func revertLastCorrectionIfPossible() -> Bool {
        guard let pending = pendingCorrectionRevert,
              let context = controller?.textDocumentProxy.documentContextBeforeInput else {
            return false
        }

        let expectedSuffix = pending.correctedWord + pending.trailingInput
        guard context.hasSuffix(expectedSuffix) else {
            pendingCorrectionRevert = nil
            return false
        }

        for _ in 0..<expectedSuffix.count {
            controller?.textDocumentProxy.deleteBackward()
        }
        let restoredText = pending.trailingInput == " " ? pending.originalWord : pending.originalWord + pending.trailingInput
        controller?.textDocumentProxy.insertText(restoredText)
        pendingDictionaryLearningCandidate = PendingDictionaryLearningCandidate(
            originalWord: pending.originalWord,
            restoredContextSuffix: restoredText
        )
        pendingCorrectionRevert = nil
        lastSpacePressTime = nil
        return true
    }

    private func shouldSuppressCorrections(for context: String) -> Bool {
        guard let token = AutocorrectionEngine.lastToken(in: context) else { return false }
        return personalDictionaryService.containsLearnedWord(token.original)
    }

    private func standaloneLowercaseIReplacement(context: String, trailingInput: String) -> AutocorrectionResult? {
        guard trailingInput == " " else { return nil }
        guard context.last == "i" else { return nil }

        guard hasStandaloneIBoundary(before: context) else {
            return nil
        }

        return AutocorrectionResult(
            charsToDelete: 1,
            corrected: "I",
            confidence: 1.0,
            source: .deterministicRule
        )
    }

    private func hasStandaloneIBoundary(before context: String) -> Bool {
        let prefix = String(context.dropLast())
        guard let previous = prefix.last else { return true }

        if previous.isLetter || previous.isNumber || previous == "'" || previous == "-" {
            return false
        }

        return true
    }

    private func processPendingDictionaryLearningIfNeeded(forNextInput input: String) -> Bool {
        guard let pending = pendingDictionaryLearningCandidate,
              let context = controller?.textDocumentProxy.documentContextBeforeInput else {
            return false
        }

        guard context.hasSuffix(pending.restoredContextSuffix) else {
            pendingDictionaryLearningCandidate = nil
            return false
        }

        if correctionSuffix(for: input) != nil {
            personalDictionaryService.recordRevertedCorrection(originalWord: pending.originalWord)
            pendingDictionaryLearningCandidate = nil
            return true
        }
        pendingDictionaryLearningCandidate = nil
        return false
    }
}
