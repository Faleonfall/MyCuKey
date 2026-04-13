import Testing
import Foundation
@testable import MyCuKey

@MainActor
struct PersonalDictionaryServiceTests {

    @Test func testAddWordIsPersistedAndNormalized() async throws {
        let service = makeIsolatedDictionaryService()

        let entry = service.addWord("MyWord")

        #expect(entry?.normalizedWord == "myword")
        #expect(service.containsLearnedWord("myword"))
        #expect(service.containsLearnedWord("MYWORD"))
        #expect(service.allWords().map(\.normalizedWord) == ["myword"])
    }

    @Test func testAddWordIsIdempotent() async throws {
        let service = makeIsolatedDictionaryService()

        _ = service.addWord("custom")
        _ = service.addWord("Custom")

        #expect(service.allWords().count == 1)
    }

    @Test func testInvalidWordsAreRejected() async throws {
        let service = makeIsolatedDictionaryService()

        #expect(service.addWord("1") == nil)
        #expect(service.addWord("   ") == nil)
        #expect(service.addWord("word with space") == nil)
        #expect(service.addWord("!!!") == nil)
        #expect(service.allWords().isEmpty)
    }

    @Test func testRevertCountsPromoteOnSecondRevert() async throws {
        let service = makeIsolatedDictionaryService()

        service.recordRevertedCorrection(originalWord: "Teh")
        #expect(service.containsLearnedWord("teh") == false)
        #expect(service.revertCount(for: "teh") == 1)

        service.recordRevertedCorrection(originalWord: "teh")
        #expect(service.containsLearnedWord("teh"))
        #expect(service.revertCount(for: "teh") == 0)
    }

    @Test func testRemoveWordClearsLearnedEntryAndPendingCount() async throws {
        let service = makeIsolatedDictionaryService()

        service.recordRevertedCorrection(originalWord: "teh")
        _ = service.addWord("teh")
        service.removeWord("teh")

        #expect(service.containsLearnedWord("teh") == false)
        #expect(service.revertCount(for: "teh") == 0)
    }

    @Test func testClearAllRemovesWordsAndCounters() async throws {
        let service = makeIsolatedDictionaryService()

        _ = service.addWord("alpha")
        service.recordRevertedCorrection(originalWord: "beta")
        service.clearAll()

        #expect(service.allWords().isEmpty)
        #expect(service.revertCount(for: "beta") == 0)
    }
}

private func makeIsolatedDictionaryService() -> PersonalDictionaryService {
    let suiteName = "test.personal-dictionary.service.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    return PersonalDictionaryService(defaults: defaults)
}
