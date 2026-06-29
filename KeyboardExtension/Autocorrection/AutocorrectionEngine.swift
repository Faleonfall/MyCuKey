import UIKit

// MARK: - Core Types
enum CorrectionSource: Equatable {
    case userInput
    case contraction
    case deterministicRule
    case localLexicon
    case nextWordLexicon
    case personalDictionary
    case shortTokenLexicon
    case supplementaryLexicon
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
    let correctionTarget: String
    let correctionTargetLowercased: String
    let leadingDecoration: String
    let trailingDecoration: String
}

struct PatternEvaluationContext: Equatable {
    let token: CorrectionToken
    let guesses: [String]
    let previousTokenLowercased: String?
    let isAtSentenceStart: Bool
}

enum SuggestionStrength: Int, Comparable {
    case helpfulAlternative = 1
    case strongRepair = 0

    static func < (lhs: SuggestionStrength, rhs: SuggestionStrength) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

struct PreparedCorrectionContext {
    let token: CorrectionToken
    let guesses: [String]
    let patternContext: PatternEvaluationContext
}

// MARK: - Autocorrection Engine
// Hybrid engine: deterministic typo fixes first, UITextChecker fallback second.
struct AutocorrectionEngine {
    let textChecker = UITextChecker()
    let suggestionProvider: any SuggestionProvider = HybridSuggestionProvider.shared
    private let decoder = UnifiedDecoder()
    private let bigram = BigramModel.shared
    private let minimumTextCheckerAutoApplyConfidence = 0.96
    // The decoder may silently commit from this length up on unigram evidence
    // alone. Shorter tokens have too many near neighbors to trust without context.
    private let minimumDecoderAutoApplyLength = 4
    // Context (#2) can rescue shorter tokens (ny -> my) but only down to here,
    // and only when the previous word decisively predicts one candidate.
    private let minimumContextAutoApplyLength = 2
    // How strongly the previous word must predict the winner, and how far ahead
    // of the runner-up, for an edit-distance tie to be broken by context.
    private let contextMinAssociation = 0.20
    private let contextMinMargin = 0.20
    // Short tokens demand a near-certain context signal before any silent commit.
    private let shortTokenMinAssociation = 0.50
    private let contextAppliedConfidence = 0.90
    // Frequency assumed for a UITextChecker word that our lexicon does not list
    // (e.g. inflections like "spent"). Modest, so it never out-ranks a known
    // common word on frequency alone — it only competes via context.
    private let systemGuessDefaultScore = 2_500.0

    // Keep this map intentionally small. The suggestion bar should grow mainly
    // through ranking and pattern logic rather than an endless typo pair list.
    private let deterministicCorrections: [String: String] = [
        // Transpositions
        "teh": "the",
        "helo": "hello",
        "adn": "and",
        "ot": "on",
        "taht": "that",
        "thier": "their",
        "becase": "because",
        "agian": "again",
        "chekc": "check",
        "anyhting": "anything",
        // Missing / extra letter classics
        "helllo": "hello",
        "recieve": "receive",
        "becuase": "because",
        "wierd": "weird",
        "actaully": "actually",
        "diffrent": "different",
        "intresting": "interesting",
        "usaully": "usually",
        "keeo": "keep",
        // Stable long-word misspellings
        "seperate": "separate",
        "definately": "definitely",
        "goverment": "government",
        "untill": "until",
        "enviroment": "environment",
        "tommorow": "tomorrow",
        "surprized": "surprised",
    ]

    func evaluate(context: String) -> AutocorrectionResult? {
        autoApplyCandidateResults(for: context)?.results.first
    }

    func suggestions(context: String, boostedTerms: [SuggestionBoostTerm] = [])
        -> AutocorrectionSuggestionSet?
    {
        guard let ranked = suggestionCandidateResults(for: context, boostedTerms: boostedTerms)
        else { return nil }

        let suggestions = ranked.results.prefix(2).map { result in
            AutocorrectionSuggestion(
                text: result.corrected,
                source: result.source,
                confidence: result.confidence
            )
        }

        guard !suggestions.isEmpty else { return nil }
        return AutocorrectionSuggestionSet(token: ranked.token, suggestions: Array(suggestions))
    }

    // MARK: - Tokenization
    static func lastToken(in context: String) -> CorrectionToken? {
        var token = ""
        for character in context.reversed() {
            if isTokenBoundary(character) {
                break
            }
            token = String(character) + token
        }

        guard !token.isEmpty else { return nil }

        let decorated = unwrapRoleplayDecoratedToken(token)
        return CorrectionToken(
            original: token,
            correctionTarget: decorated.core,
            correctionTargetLowercased: decorated.core.lowercased(),
            leadingDecoration: decorated.leadingDecoration,
            trailingDecoration: decorated.trailingDecoration
        )
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

    // MARK: - Deterministic Fixes
    private func deterministicResult(for token: CorrectionToken) -> AutocorrectionResult? {
        if let exact = deterministicCorrections[token.correctionTargetLowercased] {
            return makeResult(
                for: token,
                correctedLowercased: exact,
                confidence: 0.99,
                source: .deterministicRule
            )
        }

        guard token.correctionTargetLowercased.count > 3 else { return nil }

        if let repeatedLetterFix = collapseRepeatedLetters(in: token.correctionTargetLowercased),
            repeatedLetterFix != token.correctionTargetLowercased,
            !hasExpressiveTrailingRepeat(token.correctionTargetLowercased),
            isDictionaryWord(repeatedLetterFix)
        {
            return makeResult(
                for: token,
                correctedLowercased: repeatedLetterFix,
                confidence: 0.95,
                source: .deterministicRule
            )
        }

        return nil
    }

    // MARK: - Token Gating
    private func shouldSkipStylizedToken(_ token: String) -> Bool {
        if hasExpressiveTrailingRepeat(token.lowercased()) {
            return true
        }

        return containsInteriorRoleplayMarker(token)
    }

    private func containsInteriorRoleplayMarker(_ token: String) -> Bool {
        guard token.count >= 3 else { return false }

        let markerSet: Set<Character> = ["*", "_", "~"]
        let interior = token.dropFirst().dropLast()
        return interior.contains { markerSet.contains($0) }
    }

    private static func unwrapRoleplayDecoratedToken(_ token: String) -> (
        core: String, leadingDecoration: String, trailingDecoration: String
    ) {
        guard token.count >= 3,
            let first = token.first,
            let last = token.last,
            first == last,
            ["*", "_", "~"].contains(first)
        else {
            return (token, "", "")
        }

        let core = String(token.dropFirst().dropLast())
        guard !core.isEmpty else {
            return (token, "", "")
        }

        return (core, String(first), String(last))
    }

    // MARK: - Context Preparation
    private func makePatternContext(
        for token: CorrectionToken,
        in fullContext: String,
        guesses: [String]
    ) -> PatternEvaluationContext {
        let prefix = String(fullContext.dropLast(token.original.count))
        let previousContext = prefix.trimmingCharacters(in: .whitespacesAndNewlines)
        return PatternEvaluationContext(
            token: token,
            guesses: guesses,
            previousTokenLowercased: Self.lastToken(in: previousContext)?
                .correctionTargetLowercased,
            isAtSentenceStart: Self.isSentenceStartPrefix(prefix)
        )
    }

    private static func isSentenceStartPrefix(_ prefix: String) -> Bool {
        let trimmed = prefix.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let last = trimmed.last else { return true }
        return last == "." || last == "!" || last == "?" || last == "\n"
    }

    func preparedContext(for context: String, minimumTokenLength: Int = 2)
        -> PreparedCorrectionContext?
    {
        guard let token = Self.lastToken(in: context), token.original.count >= minimumTokenLength
        else { return nil }
        guard token.correctionTarget.count >= minimumTokenLength else { return nil }
        guard !shouldSkipStylizedToken(token.original) else { return nil }

        let guesses = textCheckerGuesses(for: token.correctionTarget).map { $0.lowercased() }
        return PreparedCorrectionContext(
            token: token,
            guesses: guesses,
            patternContext: makePatternContext(for: token, in: context, guesses: guesses)
        )
    }

    func baseCandidateResults(for prepared: PreparedCorrectionContext) -> [AutocorrectionResult] {
        [
            deterministicResult(for: prepared.token),
            patternResult(for: prepared.patternContext),
        ]
        .compactMap { $0 }
    }

    // MARK: - Result Construction
    func textCheckerResult(for token: CorrectionToken, guesses: [String]) -> AutocorrectionResult? {
        guard
            !shouldBlockTrailingDuplicateCorrection(
                input: token.correctionTargetLowercased, guesses: guesses)
        else {
            return nil
        }

        let acceptedGuesses =
            guesses
            .filter { candidate in
                shouldAcceptTextCheckerCandidate(
                    input: token.correctionTargetLowercased, candidate: candidate)
            }

        guard
            let acceptedGuess = acceptedGuesses.min(by: { lhs, rhs in
                rank(lhs, against: token.correctionTargetLowercased)
                    < rank(rhs, against: token.correctionTargetLowercased)
            })
        else {
            return nil
        }

        return makeResult(
            for: token,
            correctedLowercased: acceptedGuess,
            confidence: confidenceScore(
                input: token.correctionTargetLowercased, candidate: acceptedGuess),
            source: .textChecker
        )
    }

    func makeResult(
        for token: CorrectionToken,
        correctedLowercased: String,
        confidence: Double,
        source: CorrectionSource
    ) -> AutocorrectionResult? {
        guard correctedLowercased != token.correctionTargetLowercased else { return nil }

        let correctedCore = Self.applyCasePattern(
            from: token.correctionTarget, to: correctedLowercased)

        return AutocorrectionResult(
            charsToDelete: token.original.count,
            corrected: token.leadingDecoration + correctedCore + token.trailingDecoration,
            confidence: confidence,
            source: source
        )
    }

    // MARK: - Auto-Apply Pipeline
    private func autoApplyCandidateResults(for context: String) -> (
        token: CorrectionToken, results: [AutocorrectionResult]
    )? {
        guard let prepared = preparedContext(for: context) else { return nil }
        let baseCandidates = baseCandidateResults(for: prepared)

        let candidates: [AutocorrectionResult?] =
            baseCandidates.map { $0 } + [
                textCheckerResult(for: prepared.token, guesses: prepared.guesses).flatMap {
                    result in
                    result.confidence >= minimumTextCheckerAutoApplyConfidence ? result : nil
                },
                decoderAutoApplyResult(
                    for: prepared.token,
                    previousWord: prepared.patternContext.previousTokenLowercased,
                    systemGuesses: prepared.guesses
                ),
            ]

        var seen = Set<String>()
        let uniqueResults =
            candidates
            .compactMap { $0 }
            .filter { result in
                let key = result.corrected.lowercased()
                return seen.insert(key).inserted
            }

        guard !uniqueResults.isEmpty else { return nil }
        return (prepared.token, uniqueResults)
    }

    // Decoder-driven silent commit. The trie noisy-channel decoder proposes
    // out-of-vocabulary repairs; this picks one to apply under two regimes:
    //   - Unigram: when exactly one real word sits at the winning edit distance,
    //     commit it (peoole -> people, dobe -> done).
    //   - Context (#2): when several words tie at that distance, the previous
    //     word breaks the tie via the bigram model (slent -> spent after "i",
    //     tine -> time after "my"). Context can also rescue shorter tokens that
    //     the unigram regime is too cautious to touch (ny -> my after "spent").
    // Curated and textChecker results above take priority; this fills the gap
    // where nothing else fires. The trust guards keep both regimes safe.
    private func decoderAutoApplyResult(
        for token: CorrectionToken, previousWord: String?, systemGuesses: [String]
    ) -> AutocorrectionResult? {
        let typed = token.correctionTargetLowercased
        guard typed.count >= minimumContextAutoApplyLength else { return nil }

        // Trust guard 1: a word UITextChecker already accepts is real even when
        // it is missing from our frequency lexicon (e.g. "wifi"). Never silently
        // rewrite it. This closes the out-of-vocab false-positive hole that
        // protect-in-vocab alone cannot, since our 50k list is not exhaustive.
        guard isMisspelled(typed) else { return nil }

        // Trust guard 2: an expressive trailing run ("nooo", "yesss") is emphasis,
        // not a misspelling to rewrite.
        guard !hasExpressiveTrailingRepeat(typed) else { return nil }

        // Trust guard 3: a real word with one letter doubled ("yourr" -> your,
        // "herr" -> her) reads as a stray repeat key, not a word to silently
        // swap. Interior doubles that do not reduce to a word ("peoole" -> peole)
        // stay correctable.
        guard !hasStrayDoubledLetterFormingWord(typed) else { return nil }

        guard
            let chosen = chooseDecoderCandidate(
                for: typed, previousWord: previousWord, systemGuesses: systemGuesses)
        else {
            return nil
        }

        return makeResult(
            for: token,
            correctedLowercased: chosen.word,
            confidence: chosen.confidence,
            source: .localLexicon
        )
    }

    private func chooseDecoderCandidate(
        for typed: String, previousWord: String?, systemGuesses: [String]
    ) -> UnifiedDecoder.Candidate? {
        let trieCandidates = decoder.candidates(
            for: typed, limit: 24, includePrefixCompletions: false)
        let isShort = typed.count < minimumDecoderAutoApplyLength

        // No-context commit is reserved for our frequency-vetted trie vocabulary:
        // exactly one known word at the winning distance, on a confident token.
        // System-dictionary words (below) never commit this way; they are only
        // trustworthy when context backs them.
        if let leader = trieCandidates.first, leader.distance > 0, !isShort {
            let winners = trieCandidates.filter { $0.distance == leader.distance }
            if winners.count == 1, leader.confidence >= 0.80 {
                return leader
            }
        }

        // Context path: widen the pool with UITextChecker's guesses so common
        // inflections our lexicon omits ("spent", "things") become reachable, and
        // let the previous word pick among everything at the winning distance.
        let pool = mergeSystemGuesses(systemGuesses, into: trieCandidates, typed: typed)
        guard let leader = pool.first, leader.distance > 0 else { return nil }
        let winners = pool.filter { $0.distance == leader.distance }
        return contextResolvedCandidate(
            winners: winners, previousWord: previousWord, isShort: isShort)
    }

    // Fold UITextChecker guesses into the trie candidate list as scored
    // candidates, deduped by word (the trie's own frequency wins when it has the
    // word). Only real edits within the decoder's distance bound are kept.
    private func mergeSystemGuesses(
        _ guesses: [String],
        into trieCandidates: [UnifiedDecoder.Candidate],
        typed: String
    ) -> [UnifiedDecoder.Candidate] {
        var byWord: [String: UnifiedDecoder.Candidate] = [:]
        for candidate in trieCandidates {
            byWord[candidate.word] = candidate
        }

        for guess in guesses {
            let word = guess.lowercased()
            guard word != typed, byWord[word] == nil else { continue }
            let distance = damerauLevenshteinDistance(typed, word)
            guard distance >= 1, distance <= decoder.maxEditDistance else { continue }
            let score = decoder.trie.score(for: word) ?? systemGuessDefaultScore
            byWord[word] = decoder.scored(
                WordTrie.Match(word: word, score: score, distance: distance))
        }

        return byWord.values.sorted { lhs, rhs in
            if lhs.distance == 0 && rhs.distance != 0 { return true }
            if rhs.distance == 0 && lhs.distance != 0 { return false }
            return lhs.score > rhs.score
        }
    }

    // Break an edit-distance tie (or rescue a short token) using the bigram
    // model: the previous word must predict exactly one candidate clearly more
    // than the rest. Returns nil when context gives no decisive signal.
    private func contextResolvedCandidate(
        winners: [UnifiedDecoder.Candidate],
        previousWord: String?,
        isShort: Bool
    ) -> UnifiedDecoder.Candidate? {
        guard let previousWord, !previousWord.isEmpty else { return nil }

        let ranked =
            winners
            .map {
                (candidate: $0, association: bigram.association(prev: previousWord, next: $0.word))
            }
            .sorted { $0.association > $1.association }

        guard let best = ranked.first else { return nil }
        let runnerUp = ranked.count > 1 ? ranked[1].association : 0
        let minimumAssociation = isShort ? shortTokenMinAssociation : contextMinAssociation

        guard best.association >= minimumAssociation,
            best.association - runnerUp >= contextMinMargin
        else {
            return nil
        }

        return UnifiedDecoder.Candidate(
            word: best.candidate.word,
            score: best.candidate.score,
            distance: best.candidate.distance,
            confidence: contextAppliedConfidence
        )
    }

    // True when collapsing any one adjacent doubled letter yields a real word,
    // i.e. the token is a dictionary word with a single stray repeat key.
    private func hasStrayDoubledLetterFormingWord(_ word: String) -> Bool {
        let chars = Array(word)
        for index in 1..<chars.count where chars[index] == chars[index - 1] {
            var reduced = chars
            reduced.remove(at: index)
            if isDictionaryWord(String(reduced)) { return true }
        }
        return false
    }

    private func isMisspelled(_ word: String) -> Bool {
        let range = NSRange(location: 0, length: word.utf16.count)
        let misspelled = textChecker.rangeOfMisspelledWord(
            in: word, range: range, startingAt: 0, wrap: false, language: "en_US"
        )
        return misspelled.location != NSNotFound
    }

    // MARK: - Suggestion Pipeline
    func shouldAcceptTextCheckerCandidate(input: String, candidate: String) -> Bool {
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

    // MARK: - Scoring
    func confidenceScore(input: String, candidate: String) -> Double {
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
}
