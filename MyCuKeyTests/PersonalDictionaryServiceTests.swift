import Testing
import Foundation
@testable import MyCuKey

// MARK: - Personal Dictionary Service Tests

@MainActor
struct PersonalDictionaryServiceTests {

    // MARK: - Learned Words

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

    // MARK: - Cache and Merge Behavior

    @Test func testRepeatedLookupsUseCachedStateUntilExplicitRefresh() async throws {
        let suiteName = "test.personal-dictionary.cache.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let service = PersonalDictionaryService(defaults: defaults)
        #expect(service.containsLearnedWord("alpha") == false)

        let externalEntry = LearnedWordEntry(normalizedWord: "alpha", createdAt: Date())
        let encoded = try JSONEncoder().encode([externalEntry])
        defaults.set(encoded, forKey: PersonalDictionaryConfiguration.learnedWordsKey)

        #expect(service.containsLearnedWord("alpha") == false)

        service.refreshFromStorage()

        #expect(service.containsLearnedWord("alpha"))
    }

    @Test func testLocalWritesUpdateCacheImmediately() async throws {
        let service = makeIsolatedDictionaryService()

        _ = service.addWord("alpha")
        #expect(service.containsLearnedWord("alpha"))

        service.removeWord("alpha")
        #expect(service.containsLearnedWord("alpha") == false)
    }

    @Test func testAddWordMergesWithExternalStorageChanges() async throws {
        let suiteName = "test.personal-dictionary.merge.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let service = PersonalDictionaryService(defaults: defaults)
        let externalService = PersonalDictionaryService(defaults: defaults)

        _ = externalService.addWord("alpha")
        _ = service.addWord("beta")

        #expect(Set(service.allWords().map(\.normalizedWord)) == ["alpha", "beta"])
    }
}

// MARK: - Test Support

private func makeIsolatedDictionaryService() -> PersonalDictionaryService {
    let suiteName = "test.personal-dictionary.service.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    return PersonalDictionaryService(defaults: defaults)
}
