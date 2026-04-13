import UIKit

enum CorrectionSource: Equatable {
    case contraction
    case deterministicRule
    case textChecker
}

struct AutocorrectionResult: Equatable {
    let charsToDelete: Int
    let corrected: String
    let confidence: Double
    let source: CorrectionSource
}

struct CorrectionToken: Equatable {
    let original: String
    let lowercased: String
}

// MARK: - Autocorrection Engine
// Hybrid engine: deterministic typo fixes first, UITextChecker fallback second.
struct AutocorrectionEngine {
    private let textChecker = UITextChecker()

    private let deterministicCorrections: [String: String] = [
        "teh": "the",
        "helo": "hello",
        "helllo": "hello",
        "adn": "and",
        "taht": "that",
        "thier": "their",
        "recieve": "receive",
        "seperate": "separate",
        "definately": "definitely",
        "goverment": "government",
        "becuase": "because"
    ]

    func evaluate(context: String) -> AutocorrectionResult? {
        guard let token = Self.lastToken(in: context), token.original.count >= 2 else { return nil }
        guard token.original.count > 1 else { return nil }

        if let deterministic = deterministicResult(for: token) {
            return deterministic
        }

        return textCheckerResult(for: token)
    }

    static func lastToken(in context: String) -> CorrectionToken? {
        var token = ""
        for character in context.reversed() {
            if isTokenBoundary(character) {
                break
            }
            token = String(character) + token
        }

        guard !token.isEmpty else { return nil }
        return CorrectionToken(original: token, lowercased: token.lowercased())
    }

    static func applyCasePattern(from source: String, to corrected: String) -> String {
        if source == source.lowercased(), corrected.lowercased().hasPrefix("i'") {
            return corrected.prefix(1).uppercased() + corrected.dropFirst().lowercased()
        }

        if source == source.uppercased(), source.count > 1 {
            return corrected.uppercased()
        }

        if source.first?.isUppercase == true {
            return corrected.prefix(1).uppercased() + corrected.dropFirst().lowercased()
        }

        return corrected.lowercased()
    }

    private static func isTokenBoundary(_ character: Character) -> Bool {
        character == " " || character == "\n" || character == "\t"
    }

    private func deterministicResult(for token: CorrectionToken) -> AutocorrectionResult? {
        if let exact = deterministicCorrections[token.lowercased] {
            return makeResult(
                for: token,
                correctedLowercased: exact,
                confidence: 0.99,
                source: .deterministicRule
            )
        }

        guard token.lowercased.count > 3 else { return nil }

        if let repeatedLetterFix = collapseRepeatedLetters(in: token.lowercased),
           repeatedLetterFix != token.lowercased,
           isDictionaryWord(repeatedLetterFix) {
            return makeResult(
                for: token,
                correctedLowercased: repeatedLetterFix,
                confidence: 0.95,
                source: .deterministicRule
            )
        }

        return nil
    }

    private func textCheckerResult(for token: CorrectionToken) -> AutocorrectionResult? {
        let range = NSRange(0..<token.original.utf16.count)
        let misspelledRange = textChecker.rangeOfMisspelledWord(
            in: token.original,
            range: range,
            startingAt: 0,
            wrap: false,
            language: "en"
        )
        guard misspelledRange.location != NSNotFound else { return nil }

        guard let guesses = textChecker.guesses(forWordRange: misspelledRange, in: token.original, language: "en") else {
            return nil
        }

        let acceptedGuesses = guesses
            .map { $0.lowercased() }
            .filter { candidate in
                shouldAcceptTextCheckerCandidate(input: token.lowercased, candidate: candidate)
            }

        guard let acceptedGuess = acceptedGuesses.min(by: { lhs, rhs in
            rank(lhs, against: token.lowercased) < rank(rhs, against: token.lowercased)
        }) else {
            return nil
        }

        return makeResult(
            for: token,
            correctedLowercased: acceptedGuess,
            confidence: confidenceScore(input: token.lowercased, candidate: acceptedGuess),
            source: .textChecker
        )
    }

    private func makeResult(
        for token: CorrectionToken,
        correctedLowercased: String,
        confidence: Double,
        source: CorrectionSource
    ) -> AutocorrectionResult? {
        guard correctedLowercased != token.lowercased else { return nil }

        return AutocorrectionResult(
            charsToDelete: token.original.count,
            corrected: Self.applyCasePattern(from: token.original, to: correctedLowercased),
            confidence: confidence,
            source: source
        )
    }

    private func shouldAcceptTextCheckerCandidate(input: String, candidate: String) -> Bool {
        guard input.count >= 2, candidate != input else { return false }

        let distance = damerauLevenshteinDistance(input, candidate)
        if input.count <= 3 {
            return distance == 1 && isLikelyApostropheVariant(input: input, candidate: candidate)
        }

        if isLikelyApostropheVariant(input: input, candidate: candidate) {
            return true
        }

        if isSingleTransposition(input, candidate) {
            return true
        }

        if distance == 1 {
            return true
        }

        return distance == 2
            && input.count >= 5
            && abs(input.count - candidate.count) <= 1
            && hasSameOuterLetters(input, candidate)
            && CommonWordLexicon.contains(candidate)
    }

    private func confidenceScore(input: String, candidate: String) -> Double {
        if isLikelyApostropheVariant(input: input, candidate: candidate) {
            return 0.98
        }

        if isSingleTransposition(input, candidate) {
            return 0.96
        }

        let distance = damerauLevenshteinDistance(input, candidate)
        switch distance {
        case 0: return 0
        case 1: return 0.93
        case 2: return input.count >= 5 ? 0.84 : 0.72
        default: return 0.5
        }
    }

    private func isDictionaryWord(_ word: String) -> Bool {
        textChecker.rangeOfMisspelledWord(
            in: word,
            range: NSRange(0..<word.utf16.count),
            startingAt: 0,
            wrap: false,
            language: "en"
        ).location == NSNotFound
    }

    private func isLikelyApostropheVariant(input: String, candidate: String) -> Bool {
        candidate.contains("'") && candidate.replacingOccurrences(of: "'", with: "") == input
    }

    private func rank(_ candidate: String, against input: String) -> (Int, Int, Int, Int, Int) {
        let distance = damerauLevenshteinDistance(input, candidate)
        let lexiconBonus = CommonWordLexicon.contains(candidate) ? 0 : 1
        let subsequenceBonus = isSubsequence(input, of: candidate) || isSubsequence(candidate, of: input) ? 0 : 1
        let outerLetterPenalty = hasSameOuterLetters(input, candidate) ? 0 : 1
        let prefixScore = commonPrefixLength(input, candidate)
        let lengthDelta = abs(input.count - candidate.count)
        return (distance, lexiconBonus, outerLetterPenalty, subsequenceBonus, -prefixScore + lengthDelta)
    }

    private func hasSameOuterLetters(_ input: String, _ candidate: String) -> Bool {
        guard let inputFirst = input.first,
              let inputLast = input.last,
              let candidateFirst = candidate.first,
              let candidateLast = candidate.last else {
            return false
        }
        return inputFirst == candidateFirst && inputLast == candidateLast
    }

    private func commonPrefixLength(_ a: String, _ b: String) -> Int {
        let aChars = Array(a)
        let bChars = Array(b)
        var index = 0

        while index < aChars.count && index < bChars.count && aChars[index] == bChars[index] {
            index += 1
        }

        return index
    }

    private func isSubsequence(_ lhs: String, of rhs: String) -> Bool {
        if lhs.isEmpty {
            return true
        }

        var lhsIndex = lhs.startIndex
        for character in rhs where lhsIndex < lhs.endIndex {
            if character == lhs[lhsIndex] {
                lhs.formIndex(after: &lhsIndex)
            }
        }

        return lhsIndex == lhs.endIndex
    }

    private func isSingleTransposition(_ input: String, _ candidate: String) -> Bool {
        guard input.count == candidate.count, input.count >= 2 else { return false }

        let inputChars = Array(input)
        let candidateChars = Array(candidate)
        let mismatchedIndexes = inputChars.indices.filter { inputChars[$0] != candidateChars[$0] }
        guard mismatchedIndexes.count == 2 else { return false }

        let first = mismatchedIndexes[0]
        let second = mismatchedIndexes[1]
        return second == first + 1
            && inputChars[first] == candidateChars[second]
            && inputChars[second] == candidateChars[first]
    }

    private func collapseRepeatedLetters(in word: String) -> String? {
        var result = ""
        var previous: Character?
        var duplicateCount = 0

        for character in word {
            if character == previous {
                duplicateCount += 1
                if duplicateCount >= 2 {
                    continue
                }
            } else {
                duplicateCount = 0
            }

            result.append(character)
            previous = character
        }

        return result == word ? nil : result
    }

    // Standard Levenshtein retained for comparison/unit coverage.
    func editDistance(_ a: String, _ b: String) -> Int {
        let a = Array(a)
        let b = Array(b)
        let n = a.count
        let m = b.count
        if n == 0 { return m }
        if m == 0 { return n }

        var dp = Array(repeating: Array(repeating: 0, count: m + 1), count: n + 1)
        for i in 0...n { dp[i][0] = i }
        for j in 0...m { dp[0][j] = j }

        for i in 1...n {
            for j in 1...m {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1
                dp[i][j] = min(dp[i - 1][j] + 1, dp[i][j - 1] + 1, dp[i - 1][j - 1] + cost)
            }
        }
        return dp[n][m]
    }

    func damerauLevenshteinDistance(_ a: String, _ b: String) -> Int {
        let aChars = Array(a)
        let bChars = Array(b)
        let n = aChars.count
        let m = bChars.count

        if n == 0 { return m }
        if m == 0 { return n }

        var table = Array(repeating: Array(repeating: 0, count: m + 1), count: n + 1)
        for i in 0...n { table[i][0] = i }
        for j in 0...m { table[0][j] = j }

        for i in 1...n {
            for j in 1...m {
                let cost = aChars[i - 1] == bChars[j - 1] ? 0 : 1
                table[i][j] = min(
                    table[i - 1][j] + 1,
                    table[i][j - 1] + 1,
                    table[i - 1][j - 1] + cost
                )

                if i > 1, j > 1,
                   aChars[i - 1] == bChars[j - 2],
                   aChars[i - 2] == bChars[j - 1] {
                    table[i][j] = min(table[i][j], table[i - 2][j - 2] + 1)
                }
            }
        }

        return table[n][m]
    }
}
