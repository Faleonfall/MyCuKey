import UIKit

// MARK: - Autocorrection Engine
// Lightweight UITextChecker wrapper — only corrects single-edit typos (edit distance ≤ 1).
struct AutocorrectionEngine {
    
    private let textChecker = UITextChecker()
    
    // Checks last word via UITextChecker, returns correction only if edit distance ≤ 1.
    // This catches single-character typos without "ducking"-style overcorrections.
    func evaluate(context: String) -> (charsToDelete: Int, corrected: String)? {
        var lastWord = ""
        for char in context.reversed() {
            guard char != " ", char != "\n" else { break }
            lastWord = String(char) + lastWord
        }
        guard lastWord.count >= 2 else { return nil } // Never autocorrect single chars
        
        let range = NSRange(0..<lastWord.utf16.count)
        let misspelledRange = textChecker.rangeOfMisspelledWord(
            in: lastWord, range: range, startingAt: 0, wrap: false, language: "en"
        )
        guard misspelledRange.location != NSNotFound else { return nil }
        
        guard let guesses = textChecker.guesses(forWordRange: misspelledRange, in: lastWord, language: "en"),
              let bestGuess = guesses.first else { return nil }
        
        // High confidence filter: only correct single-edit typos
        guard editDistance(lastWord.lowercased(), bestGuess.lowercased()) <= 1 else { return nil }
        
        // Preserve original capitalization pattern
        let corrected: String
        if lastWord == lastWord.uppercased() && lastWord.count > 1 {
            corrected = bestGuess.uppercased()
        } else if lastWord.first?.isUppercase == true {
            corrected = bestGuess.prefix(1).uppercased() + bestGuess.dropFirst().lowercased()
        } else {
            corrected = bestGuess.lowercased()
        }
        
        return (charsToDelete: lastWord.count, corrected: corrected)
    }
    
    // Levenshtein edit distance — O(n*m), negligible on short words
    func editDistance(_ a: String, _ b: String) -> Int {
        let a = Array(a), b = Array(b)
        let n = a.count, m = b.count
        if n == 0 { return m }
        if m == 0 { return n }
        
        var dp = Array(repeating: Array(repeating: 0, count: m + 1), count: n + 1)
        for i in 0...n { dp[i][0] = i }
        for j in 0...m { dp[0][j] = j }
        
        for i in 1...n {
            for j in 1...m {
                let cost = a[i-1] == b[j-1] ? 0 : 1
                dp[i][j] = min(dp[i-1][j] + 1, dp[i][j-1] + 1, dp[i-1][j-1] + cost)
            }
        }
        return dp[n][m]
    }
}
