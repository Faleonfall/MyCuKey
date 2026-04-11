import Testing
import Foundation
@testable import MyCuKey

@MainActor
struct ContractionTests {
    
    @Test func testContractionDontDetected() async throws {
        let handler = KeyboardActionHandler()
        let result = handler.contractionEngine.evaluate(context: "I dont")
        #expect(result?.corrected == "don't", "Should correct 'dont' to 'don't'.")
        #expect(result?.charsToDelete == 4, "Should delete 4 chars for 'dont'.")
    }
    
    @Test func testContractionCapitalized() async throws {
        let handler = KeyboardActionHandler()
        let result = handler.contractionEngine.evaluate(context: "Dont")
        #expect(result?.corrected == "Don't", "Should preserve leading capital: 'Dont' → 'Don't'.")
    }
    
    @Test func testContractionNoMatchReturnsNil() async throws {
        let handler = KeyboardActionHandler()
        let result = handler.contractionEngine.evaluate(context: "hello")
        #expect(result == nil, "Non-contraction word must return nil.")
    }
    
    @Test func testContractionEmptyContextReturnsNil() async throws {
        let handler = KeyboardActionHandler()
        let result = handler.contractionEngine.evaluate(context: "")
        #expect(result == nil, "Empty context must return nil.")
    }
    
    @Test func testContractionAfterSentence() async throws {
        let handler = KeyboardActionHandler()
        let result = handler.contractionEngine.evaluate(context: "This is done. I cant")
        #expect(result?.corrected == "can't", "Should detect 'cant' at end of sentence.")
        #expect(result?.charsToDelete == 4)
    }
    
    @Test func testContractionImCorrection() async throws {
        let handler = KeyboardActionHandler()
        let result = handler.contractionEngine.evaluate(context: "im")
        #expect(result?.corrected == "I'm", "Should correct 'im' to 'I'm'.")
    }
}
