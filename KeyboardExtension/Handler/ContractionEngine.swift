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
        "id"       : "I'd",
        "ill"      : "I'll",
        "youve"    : "you've",
        "youll"    : "you'll",
        "lets"     : "let's",
        "theres"   : "there's",
        "heres"    : "here's",
        "werent"   : "weren't",
        "hasnt"    : "hasn't"
    ]

    func evaluate(context: String) -> AutocorrectionResult? {
        guard let token = AutocorrectionEngine.lastToken(in: context) else { return nil }
        guard let corrected = contractionMap[token.lowercased] else { return nil }

        return AutocorrectionResult(
            charsToDelete: token.original.count,
            corrected: AutocorrectionEngine.applyCasePattern(from: token.original, to: corrected),
            confidence: 1.0,
            source: .contraction
        )
    }
}
