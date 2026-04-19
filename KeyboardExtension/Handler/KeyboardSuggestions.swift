import Foundation
import UIKit

// MARK: - Suggestion State

struct SuggestionBarState: Equatable {
    let originalToken: String
    let suggestions: [AutocorrectionSuggestion]
    let trailingSuffix: String
}

// MARK: - Suggestion Bar Flow

extension KeyboardActionHandler {
    func refreshSuggestions(for currentContext: String?) {
        guard !suppressSuggestionRefreshUntilNextToken else {
            clearSuggestions()
            return
        }

        guard currentKeyboardType == .alphabetic,
              let context = currentContext,
              let target = suggestionTarget(for: context),
              let suggestionSet = autocorrectionEngine.suggestions(context: target.suggestionContext),
              !suggestionSet.suggestions.isEmpty else {
            clearSuggestions()
            return
        }

        suggestionBarState = SuggestionBarState(
            originalToken: target.token.original,
            suggestions: Array(suggestionSet.suggestions.prefix(2)),
            trailingSuffix: target.trailingSuffix
        )
    }

    func clearSuggestions() {
        suggestionBarState = nil
    }

    func applyOriginalSuggestion() {
        guard let state = suggestionBarState else { return }
        applySuggestionText(state.originalToken)
    }

    func applySuggestion(_ suggestion: AutocorrectionSuggestion) {
        applySuggestionText(suggestion.text)
    }

    // Suggestions can target the just-committed word after space, so this
    // replacement path must preserve any existing trailing whitespace.
    private func applySuggestionText(_ replacement: String) {
        guard currentKeyboardType == .alphabetic,
              let context = controller?.textDocumentProxy.documentContextBeforeInput,
              let target = suggestionTarget(for: context) else {
            clearSuggestions()
            return
        }

        let token = target.token
        let trailingSuffix = target.trailingSuffix

        pendingCorrectionRevert = nil
        pendingDictionaryLearningCandidate = nil
        lastSpacePressTime = nil
        pendingSuggestionCommittedSpace = trailingSuffix.isEmpty
        suppressSuggestionRefreshUntilNextToken = true
        clearSuggestions()

        guard token.original != replacement else {
            if trailingSuffix.isEmpty {
                let committedContext = context + " "
                controller?.textDocumentProxy.insertText(" ")
                evaluateAutoCapitalization(contextBefore: committedContext)
            } else {
                evaluateAutoCapitalization(contextBefore: context)
            }
            DispatchQueue.main.async { [weak self] in
                self?.clearSuggestions()
            }
            return
        }

        let decoratedReplacement = token.leadingDecoration + replacement + token.trailingDecoration

        if !trailingSuffix.isEmpty {
            for _ in 0..<trailingSuffix.count {
                controller?.textDocumentProxy.deleteBackward()
            }
        }

        applyWordReplacement(
            oldWord: token.original,
            newWord: decoratedReplacement,
            originalContext: target.activeContext,
            trailingInput: trailingSuffix.isEmpty ? " " : trailingSuffix,
            tracksCorrectionRevert: false
        )
    }

    func applyWordReplacement(
        oldWord: String,
        newWord: String,
        originalContext: String,
        trailingInput: String,
        tracksCorrectionRevert: Bool
    ) {
        let prefixLen = commonPrefixLength(oldWord, newWord)
        let deleteCount = oldWord.count - prefixLen
        let insertSuffix = String(newWord.dropFirst(prefixLen)) + trailingInput

        for _ in 0..<deleteCount {
            controller?.textDocumentProxy.deleteBackward()
        }

        controller?.textDocumentProxy.insertText(insertSuffix)

        if !tracksCorrectionRevert {
            pendingCorrectionRevert = nil
        }

        let newContext = controller?.textDocumentProxy.documentContextBeforeInput
            ?? (String(originalContext.dropLast(oldWord.count)) + newWord + trailingInput)
        evaluateAutoCapitalization(contextBefore: newContext)
        refreshSuggestions(for: newContext)
    }

    // MARK: - Suggestion Targeting

    // Normalize wrappers for lookup, but keep the original token around so a
    // chosen suggestion can be re-wrapped when it is applied back to the field.
    private func suggestionTarget(for context: String) -> (activeContext: String, suggestionContext: String, token: CorrectionToken, trailingSuffix: String)? {
        let trailingWhitespace = String(context.reversed().prefix { character in
            character == " " || character == "\n" || character == "\t"
        }.reversed())

        let activeContext = trailingWhitespace.isEmpty
            ? context
            : String(context.dropLast(trailingWhitespace.count))

        guard let token = suggestionToken(in: activeContext),
              token.correctionTarget.count >= 2,
              token.correctionTarget.last?.isLetter == true else {
            return nil
        }

        let suggestionContext = String(activeContext.dropLast(token.original.count)) + token.correctionTarget
        return (activeContext, suggestionContext, token, trailingWhitespace)
    }

    private func suggestionToken(in context: String) -> CorrectionToken? {
        var rawToken = ""
        for character in context.reversed() {
            if character == " " || character == "\n" || character == "\t" {
                break
            }
            rawToken = String(character) + rawToken
        }

        guard !rawToken.isEmpty else { return nil }

        var core = rawToken
        var leadingDecoration = ""
        var trailingDecoration = ""

        while let first = core.first, !isSuggestionCoreCharacter(first) {
            leadingDecoration.append(first)
            core.removeFirst()
        }

        while let last = core.last, !isSuggestionCoreCharacter(last) {
            trailingDecoration.insert(last, at: trailingDecoration.startIndex)
            core.removeLast()
        }

        guard !core.isEmpty else { return nil }

        return CorrectionToken(
            original: rawToken,
            correctionTarget: core,
            correctionTargetLowercased: core.lowercased(),
            leadingDecoration: leadingDecoration,
            trailingDecoration: trailingDecoration
        )
    }

    private func isSuggestionCoreCharacter(_ character: Character) -> Bool {
        character.isLetter || character.isNumber || character == "'"
    }
}
