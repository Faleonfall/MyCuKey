import Foundation

// MARK: - Suggestion Bar Models

enum SuggestionMode: Equatable {
    case currentToken
    case nextWord
}

enum SuggestionBarCellRole: Equatable {
    case original
    case suggestion
    case prediction
}

struct SuggestionBarCell: Equatable {
    let text: String
    let source: CorrectionSource
    let role: SuggestionBarCellRole
    let confidence: Double
}

struct SuggestionBarState: Equatable {
    let mode: SuggestionMode
    let cells: [SuggestionBarCell]
    let context: SuggestionContext

    var originalToken: String? {
        cells.first(where: { $0.role == .original })?.text
    }

    var suggestions: [AutocorrectionSuggestion] {
        cells
            .filter { $0.role != .original }
            .map {
                AutocorrectionSuggestion(
                    text: $0.text,
                    source: $0.source,
                    confidence: $0.confidence
                )
            }
    }

    var trailingSuffix: String {
        context.trailingSuffix
    }
}

// MARK: - Suggestion Context

struct SuggestionContext: Equatable {
    let mode: SuggestionMode
    let rawContext: String
    let activeContext: String
    let suggestionContext: String?
    let token: CorrectionToken?
    let previousTokens: [String]
    let isAtSentenceStart: Bool
    let trailingBoundary: String
    let predictionInsertionPrefix: String
    let trailingSuffix: String

    static func parse(_ context: String) -> SuggestionContext? {
        let trailingWhitespace = String(context.reversed().prefix { isWhitespace($0) }.reversed())
        if !trailingWhitespace.isEmpty {
            let activeContext = String(context.dropLast(trailingWhitespace.count))
            return nextWordContext(
                rawContext: context,
                activeContext: activeContext,
                trailingBoundary: trailingWhitespace,
                predictionInsertionPrefix: ""
            )
        }

        if let last = context.last, isSentenceTerminal(last) {
            return nextWordContext(
                rawContext: context,
                activeContext: context,
                trailingBoundary: String(last),
                predictionInsertionPrefix: " "
            )
        }

        guard let token = suggestionToken(in: context),
              token.correctionTarget.count >= 1,
              token.correctionTarget.last?.isLetter == true else {
            return nil
        }

        let prefix = String(context.dropLast(token.original.count))
        let suggestionContext = prefix + token.correctionTarget
        return SuggestionContext(
            mode: .currentToken,
            rawContext: context,
            activeContext: context,
            suggestionContext: suggestionContext,
            token: token,
            previousTokens: wordTokens(in: prefix),
            isAtSentenceStart: isSentenceStart(after: prefix, trailingBoundary: ""),
            trailingBoundary: "",
            predictionInsertionPrefix: "",
            trailingSuffix: ""
        )
    }

    // MARK: - Context Construction

    private static func nextWordContext(
        rawContext: String,
        activeContext: String,
        trailingBoundary: String,
        predictionInsertionPrefix: String
    ) -> SuggestionContext {
        let sentenceStart = isSentenceStart(after: activeContext, trailingBoundary: trailingBoundary)
        return SuggestionContext(
            mode: .nextWord,
            rawContext: rawContext,
            activeContext: activeContext,
            suggestionContext: nil,
            token: nil,
            previousTokens: sentenceStart ? [] : wordTokens(in: activeContext),
            isAtSentenceStart: sentenceStart,
            trailingBoundary: trailingBoundary,
            predictionInsertionPrefix: predictionInsertionPrefix,
            trailingSuffix: trailingBoundary
        )
    }

    // MARK: - Tokenization

    private static func suggestionToken(in context: String) -> CorrectionToken? {
        var rawToken = ""
        for character in context.reversed() {
            if isWhitespace(character) {
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

    private static func wordTokens(in text: String) -> [String] {
        var tokens: [String] = []
        var current = ""

        for character in text {
            if isSuggestionCoreCharacter(character) || character == "-" {
                current.append(character)
            } else if !current.isEmpty {
                tokens.append(current.lowercased())
                current = ""
            }
        }

        if !current.isEmpty {
            tokens.append(current.lowercased())
        }

        return tokens.filter { token in
            token.contains(where: \.isLetter)
        }
    }

    // MARK: - Boundary Helpers

    private static func isSentenceStart(after activeContext: String, trailingBoundary: String) -> Bool {
        if trailingBoundary.contains("\n") {
            return true
        }

        let trimmed = activeContext.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let last = trimmed.last else { return true }
        return isSentenceTerminal(last)
    }

    private static func isWhitespace(_ character: Character) -> Bool {
        character == " " || character == "\n" || character == "\t"
    }

    private static func isSentenceTerminal(_ character: Character) -> Bool {
        character == "." || character == "!" || character == "?"
    }

    private static func isSuggestionCoreCharacter(_ character: Character) -> Bool {
        character.isLetter || character.isNumber || character == "'"
    }
}
