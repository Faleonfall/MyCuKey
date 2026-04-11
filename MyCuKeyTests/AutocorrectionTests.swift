import Testing
import Foundation
@testable import MyCuKey

@MainActor
struct AutocorrectionTests {
    
    // MARK: - Edit Distance
    @Test func testEditDistanceIdentical() async throws {
        let engine = AutocorrectionEngine()
        #expect(engine.editDistance("hello", "hello") == 0)
    }
    
    @Test func testEditDistanceSingleMissingLetter() async throws {
        let engine = AutocorrectionEngine()
        #expect(engine.editDistance("helo", "hello") == 1, "Missing letter = 1 edit.")
    }
    
    @Test func testEditDistanceSingleExtraLetter() async throws {
        let engine = AutocorrectionEngine()
        #expect(engine.editDistance("helloo", "hello") == 1, "Extra letter = 1 edit.")
    }
    
    @Test func testEditDistanceTransposition() async throws {
        let engine = AutocorrectionEngine()
        // Levenshtein counts transposition as 2 edits (delete + insert)
        #expect(engine.editDistance("hlelo", "hello") == 2)
    }
    
    @Test func testEditDistanceEmpty() async throws {
        let engine = AutocorrectionEngine()
        #expect(engine.editDistance("", "hello") == 5)
        #expect(engine.editDistance("hello", "") == 5)
    }
    
    // MARK: - Autocorrection Engine
    @Test func testAutocorrectionSkipsSingleChar() async throws {
        let engine = AutocorrectionEngine()
        #expect(engine.evaluate(context: "x") == nil, "Single char words must never be autocorrected.")
    }
    
    @Test func testAutocorrectionSkipsCorrectWord() async throws {
        let engine = AutocorrectionEngine()
        #expect(engine.evaluate(context: "hello") == nil, "Correctly spelled words must return nil.")
    }
    
    @Test func testAutocorrectionSkipsEmptyContext() async throws {
        let engine = AutocorrectionEngine()
        #expect(engine.evaluate(context: "") == nil, "Empty context must return nil.")
    }
}
