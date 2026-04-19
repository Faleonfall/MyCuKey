import Testing
import Foundation
@testable import MyCuKey

// MARK: - Word Deletion Tests

@MainActor
struct WordDeletionTests {

    @Test func testWordDeletionCountForSingleWord() async throws {
        let handler = KeyboardActionHandler()
        #expect(handler.charsToDeleteForWordBackward(context: "Hello") == 5, "Should delete all 5 chars of a single word.")
    }
    
    @Test func testWordDeletionCountForMultipleWords() async throws {
        let handler = KeyboardActionHandler()
        #expect(handler.charsToDeleteForWordBackward(context: "Hello world") == 5, "Should delete only the last word 'world'.")
    }
    
    @Test func testWordDeletionCountWithTrailingSpace() async throws {
        let handler = KeyboardActionHandler()
        #expect(handler.charsToDeleteForWordBackward(context: "Hello world ") == 6, "Should delete trailing space AND the last word.")
    }
    
    @Test func testWordDeletionCountForEmptyContext() async throws {
        let handler = KeyboardActionHandler()
        #expect(handler.charsToDeleteForWordBackward(context: "") == 0, "Empty context must return 0.")
    }
    
    @Test func testWordDeletionCountWithNewline() async throws {
        let handler = KeyboardActionHandler()
        #expect(handler.charsToDeleteForWordBackward(context: "Hello\n") == 1, "Trailing newline should be deleted as one unit.")
    }
    
    @Test func testWordDeletionCountSingleCharWord() async throws {
        let handler = KeyboardActionHandler()
        #expect(handler.charsToDeleteForWordBackward(context: "I am") == 2, "Should delete 'am' (2 chars).")
    }
}
