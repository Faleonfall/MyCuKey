import Foundation

// MARK: - Contraction Engine
// Standalone struct — pure, stateless, zero dependencies.
struct ContractionEngine {
    
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
    
    // Checks if the last word in context is an uncorrected contraction.
    // Returns (charsToDelete, correctedWord) if a match is found.
    func evaluate(context: String) -> (charsToDelete: Int, corrected: String)? {
        var lastWord = ""
        for char in context.reversed() {
            guard char != " ", char != "\n" else { break }
            lastWord = String(char) + lastWord
        }
        guard !lastWord.isEmpty else { return nil }
        
        let lower = lastWord.lowercased()
        guard let corrected = contractionMap[lower] else { return nil }
        
        // Preserve leading capital e.g. "Dont" → "Don't"
        let finalCorrected = lastWord.first?.isUppercase == true
            ? corrected.prefix(1).uppercased() + corrected.dropFirst()
            : corrected
        
        return (charsToDelete: lastWord.count, corrected: finalCorrected)
    }
}
