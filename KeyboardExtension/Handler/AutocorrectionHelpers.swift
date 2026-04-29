import UIKit

// MARK: - Spellchecker Access

extension AutocorrectionEngine {
    func textCheckerGuesses(for word: String) -> [String] {
        let range = NSRange(0..<word.utf16.count)
        let misspelledRange = textChecker.rangeOfMisspelledWord(
            in: word,
            range: range,
            startingAt: 0,
            wrap: false,
            language: "en"
        )
        guard misspelledRange.location != NSNotFound else { return [] }

        return textChecker.guesses(forWordRange: misspelledRange, in: word, language: "en") ?? []
    }

    func isDictionaryWord(_ word: String) -> Bool {
        textChecker.rangeOfMisspelledWord(
            in: word,
            range: NSRange(0..<word.utf16.count),
            startingAt: 0,
            wrap: false,
            language: "en"
        ).location == NSNotFound
    }

    // MARK: - Candidate Ranking

    func isLikelyApostropheVariant(input: String, candidate: String) -> Bool {
        candidate.contains("'") && candidate.replacingOccurrences(of: "'", with: "") == input
    }

    func rank(_ candidate: String, against input: String) -> (Int, Int, Int, Int, Int) {
        let distance = damerauLevenshteinDistance(input, candidate)
        let lexiconBonus = CommonWordLexicon.contains(candidate) ? 0 : 1
        let subsequenceBonus = isSubsequence(input, of: candidate) || isSubsequence(candidate, of: input) ? 0 : 1
        let outerLetterPenalty = hasSameOuterLetters(input, candidate) ? 0 : 1
        let prefixScore = commonPrefixLength(input, candidate)
        let lengthDelta = abs(input.count - candidate.count)
        return (distance, lexiconBonus, outerLetterPenalty, subsequenceBonus, -prefixScore + lengthDelta)
    }

    // MARK: - Shape Checks

    func hasSameOuterLetters(_ input: String, _ candidate: String) -> Bool {
        guard let inputFirst = input.first,
              let inputLast = input.last,
              let candidateFirst = candidate.first,
              let candidateLast = candidate.last else {
            return false
        }
        return inputFirst == candidateFirst && inputLast == candidateLast
    }

    func commonPrefixLength(_ a: String, _ b: String) -> Int {
        let aChars = Array(a)
        let bChars = Array(b)
        var index = 0

        while index < aChars.count && index < bChars.count && aChars[index] == bChars[index] {
            index += 1
        }

        return index
    }

    func isSubsequence(_ lhs: String, of rhs: String) -> Bool {
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

    func isSingleTransposition(_ input: String, _ candidate: String) -> Bool {
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

    func keyboardNeighborSubstitutionCount(input: String, candidate: String) -> Int {
        guard input.count == candidate.count else { return 0 }

        let inputChars = Array(input)
        let candidateChars = Array(candidate)
        var count = 0

        for index in inputChars.indices where inputChars[index] != candidateChars[index] {
            let typed = inputChars[index]
            let corrected = candidateChars[index]
            if Self.keyboardNeighborMap[typed]?.contains(corrected) == true {
                count += 1
            }
        }

        return count
    }

    // MARK: - Normalization

    func collapseRepeatedLetters(in word: String) -> String? {
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

    func hasExpressiveTrailingRepeat(_ word: String) -> Bool {
        guard let lastCharacter = word.last else { return false }

        var runLength = 0
        for character in word.reversed() {
            guard character == lastCharacter else { break }
            runLength += 1
        }

        return runLength >= 3
    }

    // MARK: - Distance Metrics

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
