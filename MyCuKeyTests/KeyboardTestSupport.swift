import UIKit
@testable import MyCuKey

// MARK: - Shared Keyboard Test Support

func makeIsolatedService() -> PersonalDictionaryService {
    let suiteName = "test.personal-dictionary.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    return PersonalDictionaryService(defaults: defaults)
}

final class MockKeyboardController: UIInputViewController {
    let mockProxy: MockTextDocumentProxy

    init(beforeInput: String = "", afterInput: String = "") {
        self.mockProxy = MockTextDocumentProxy(beforeInput: beforeInput, afterInput: afterInput)
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var textDocumentProxy: UITextDocumentProxy {
        mockProxy
    }
}

final class MockTextDocumentProxy: NSObject, UITextDocumentProxy {
    var documentContextBeforeInput: String?
    var documentContextAfterInput: String?
    var selectedText: String?
    var documentInputMode: UITextInputMode?
    var documentIdentifier: UUID

    init(beforeInput: String = "", afterInput: String = "") {
        self.documentContextBeforeInput = beforeInput
        self.documentContextAfterInput = afterInput
        self.documentIdentifier = UUID()
    }

    var hasText: Bool {
        !(documentContextBeforeInput ?? "").isEmpty || !(documentContextAfterInput ?? "").isEmpty
    }

    func insertText(_ text: String) {
        documentContextBeforeInput = (documentContextBeforeInput ?? "") + text
    }

    func deleteBackward() {
        guard var before = documentContextBeforeInput, !before.isEmpty else { return }
        before.removeLast()
        documentContextBeforeInput = before
    }

    func adjustTextPosition(byCharacterOffset offset: Int) {
        guard offset != 0 else { return }

        if offset < 0 {
            for _ in 0..<abs(offset) {
                guard var before = documentContextBeforeInput, let moved = before.popLast() else { break }
                documentContextBeforeInput = before
                documentContextAfterInput = String(moved) + (documentContextAfterInput ?? "")
            }
        } else {
            for _ in 0..<offset {
                guard var after = documentContextAfterInput, !after.isEmpty else { break }
                let moved = after.removeFirst()
                documentContextAfterInput = after
                documentContextBeforeInput = (documentContextBeforeInput ?? "") + String(moved)
            }
        }
    }

    func setMarkedText(_ markedText: String, selectedRange: NSRange) {}
    func unmarkText() {}
}
