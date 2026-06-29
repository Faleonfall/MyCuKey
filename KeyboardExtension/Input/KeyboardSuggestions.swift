import Foundation
import UIKit

// MARK: - Suggestion Bar Flow
extension KeyboardActionHandler {
    func refreshSuggestions(for currentContext: String?) {
        guard !suppressSuggestionRefreshUntilNextToken else {
            clearSuggestions()
            return
        }

        guard currentKeyboardType == .alphabetic,
            let context = currentContext,
            let suggestionContext = SuggestionContext.parse(context)
        else {
            clearSuggestions()
            return
        }

        refreshSupplementaryLexiconIfNeeded()

        switch suggestionContext.mode {
        case .currentToken:
            refreshCurrentTokenSuggestions(for: suggestionContext)
        case .nextWord:
            refreshNextWordSuggestions(for: suggestionContext)
        }
    }

    func clearSuggestions() {
        suggestionBarState = nil
    }

    private func refreshCurrentTokenSuggestions(for context: SuggestionContext) {
        guard let token = context.token,
            let currentWordContext = context.suggestionContext
        else {
            clearSuggestions()
            return
        }

        let engineSet = autocorrectionEngine.suggestions(
            context: currentWordContext,
            boostedTerms: suggestionBoostTerms()
        )

        var suggestionCells: [SuggestionBarCell] = []

        // Phase 2 spatial: surface the spatially-decoded word first when the tap
        // buffer cleanly matches the typed token (otherwise this is inert).
        if let spatialText = spatialSuggestionText(for: token) {
            suggestionCells.append(
                SuggestionBarCell(
                    text: spatialText,
                    source: .localLexicon,
                    role: .suggestion,
                    confidence: 0.9
                ))
        }

        for suggestion in engineSet?.suggestions ?? [] {
            if suggestionCells.contains(where: {
                $0.text.lowercased() == suggestion.text.lowercased()
            }) {
                continue
            }
            suggestionCells.append(
                SuggestionBarCell(
                    text: suggestion.text,
                    source: suggestion.source,
                    role: .suggestion,
                    confidence: suggestion.confidence
                ))
        }

        suggestionCells = Array(suggestionCells.prefix(2))
        guard !suggestionCells.isEmpty else {
            clearSuggestions()
            return
        }

        let cells =
            [
                SuggestionBarCell(
                    text: token.original,
                    source: .userInput,
                    role: .original,
                    confidence: 1.0
                )
            ] + suggestionCells

        suggestionBarState = SuggestionBarState(
            mode: .currentToken,
            cells: cells,
            context: context
        )
    }

    // Phase 2: spatial-decoded candidate for the in-progress word. Returns nil
    // unless every letter of the token has a recorded tap and the keyboard
    // geometry is known, so a tap/text desync simply yields no contribution.
    private func spatialSuggestionText(for token: CorrectionToken) -> String? {
        let target = token.correctionTarget
        guard currentTokenTaps.count == target.count,
            target.count >= 3,
            liveKeyCenters.count >= 15
        else {
            return nil
        }
        let pitch = estimatedKeyPitch()
        guard pitch > 0 else { return nil }

        let candidates = spatialDecoder.decodeTaps(
            currentTokenTaps,
            centers: liveKeyCenters,
            sigma: pitch * 0.9,
            limit: 3
        )
        guard let best = candidates.first,
            best.word.lowercased() != target.lowercased(),
            best.confidence >= 0.5
        else {
            return nil
        }
        return AutocorrectionEngine.applyCasePattern(from: target, to: best.word)
    }

    private func estimatedKeyPitch() -> CGFloat {
        let centers = "qwertyuiop".compactMap { liveKeyCenters[$0] }
        guard centers.count >= 2 else { return 0 }
        let xs = centers.map(\.x).sorted()
        var gaps: [CGFloat] = []
        for index in 1..<xs.count {
            gaps.append(xs[index] - xs[index - 1])
        }
        guard !gaps.isEmpty else { return 0 }
        return gaps.reduce(0, +) / CGFloat(gaps.count)
    }

    private func refreshNextWordSuggestions(for context: SuggestionContext) {
        let cells = NextWordSuggestionProvider.shared.suggestions(for: context)
        guard !cells.isEmpty else {
            clearSuggestions()
            return
        }

        suggestionBarState = SuggestionBarState(
            mode: .nextWord,
            cells: cells,
            context: context
        )
    }

    // Personal and system lexicon words are shown as bar options only. They
    // should not make silent autocorrection more aggressive.
    private func suggestionBoostTerms() -> [SuggestionBoostTerm] {
        personalDictionaryService.refreshFromStorage()

        let personalTerms = personalDictionaryService.allWords().map {
            SuggestionBoostTerm(word: $0.normalizedWord, source: .personalDictionary)
        }
        let supplementaryTerms = supplementarySuggestionTerms.map {
            SuggestionBoostTerm(word: $0, source: .supplementaryLexicon)
        }

        return personalTerms + supplementaryTerms
    }

    private func refreshSupplementaryLexiconIfNeeded() {
        guard !hasRequestedSupplementaryLexicon,
            let controller
        else {
            return
        }

        hasRequestedSupplementaryLexicon = true
        controller.requestSupplementaryLexicon { [weak self] lexicon in
            let normalizedTerms = Set(
                lexicon.entries.flatMap { entry in
                    [entry.userInput, entry.documentText].compactMap(
                        KeyboardActionHandler.normalizedSuggestionTerm)
                })

            DispatchQueue.main.async {
                guard let self else { return }
                self.supplementarySuggestionTerms = normalizedTerms
                self.refreshSuggestions(
                    for: self.controller?.textDocumentProxy.documentContextBeforeInput)
            }
        }
    }

    nonisolated private static func normalizedSuggestionTerm(_ word: String) -> String? {
        PersonalDictionaryService.normalizeLearnableWord(word)
    }

    func applyOriginalSuggestion() {
        guard let originalCell = suggestionBarState?.cells.first(where: { $0.role == .original })
        else { return }
        applyCell(originalCell)
    }

    func applySuggestion(_ suggestion: AutocorrectionSuggestion) {
        guard let state = suggestionBarState else { return }

        switch state.mode {
        case .currentToken:
            applyCurrentTokenSuggestionText(suggestion.text)
        case .nextWord:
            applyPredictionText(suggestion.text)
        }
    }

    func applyCell(_ cell: SuggestionBarCell) {
        guard let state = suggestionBarState else { return }

        switch (state.mode, cell.role) {
        case (.nextWord, _), (_, .prediction):
            applyPredictionText(cell.text)
        case (.currentToken, _):
            applyCurrentTokenSuggestionText(cell.text)
        }
    }

    // Suggestions can target a decorated current token, so this replacement path
    // keeps wrappers such as quotes or roleplay markers attached to the chosen word.
    private func applyCurrentTokenSuggestionText(_ replacement: String) {
        guard currentKeyboardType == .alphabetic,
            let context = controller?.textDocumentProxy.documentContextBeforeInput,
            let target = SuggestionContext.parse(context),
            target.mode == .currentToken,
            let token = target.token
        else {
            clearSuggestions()
            return
        }

        pendingCorrectionRevert = nil
        pendingDictionaryLearningCandidate = nil
        lastSpacePressTime = nil
        pendingSuggestionCommittedSpace = target.trailingSuffix.isEmpty
        suppressSuggestionRefreshUntilNextToken = true
        clearSuggestions()

        guard token.original != replacement else {
            if target.trailingSuffix.isEmpty {
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

        if !target.trailingSuffix.isEmpty {
            for _ in 0..<target.trailingSuffix.count {
                controller?.textDocumentProxy.deleteBackward()
            }
        }

        applyWordReplacement(
            oldWord: token.original,
            newWord: decoratedReplacement,
            originalContext: target.activeContext,
            trailingInput: target.trailingSuffix.isEmpty ? " " : target.trailingSuffix,
            tracksCorrectionRevert: false
        )
    }

    private func applyPredictionText(_ prediction: String) {
        guard currentKeyboardType == .alphabetic,
            let context = controller?.textDocumentProxy.documentContextBeforeInput,
            let target = SuggestionContext.parse(context),
            target.mode == .nextWord
        else {
            clearSuggestions()
            return
        }

        pendingCorrectionRevert = nil
        pendingDictionaryLearningCandidate = nil
        lastSpacePressTime = nil
        pendingSuggestionCommittedSpace = true
        pendingSuggestionSpaceTapCount = 0
        suppressSuggestionRefreshUntilNextToken = false
        clearSuggestions()

        let insertion = target.predictionInsertionPrefix + prediction + " "
        controller?.textDocumentProxy.insertText(insertion)

        let newContext = context + insertion
        evaluateAutoCapitalization(contextBefore: newContext)
        refreshSuggestions(for: newContext)
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

        let newContext =
            controller?.textDocumentProxy.documentContextBeforeInput
            ?? (String(originalContext.dropLast(oldWord.count)) + newWord + trailingInput)
        evaluateAutoCapitalization(contextBefore: newContext)
        refreshSuggestions(for: newContext)
    }
}
