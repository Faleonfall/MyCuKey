import Testing
import SwiftUI
@testable import MyCuKey

@MainActor
struct SuggestionBarSnapshotTests {
    private let size = CGSize(width: 390, height: 32)

    private func bar(_ state: SuggestionBarState?) -> some View {
        SuggestionBarView(state: state, actionHandler: KeyboardActionHandler())
            .background(Color(UIColor.systemBackground))
    }

    private func state(_ cells: [SuggestionBarCell], token: String) -> SuggestionBarState {
        SuggestionBarState(mode: .currentToken, cells: cells, context: SuggestionContext.parse(token)!)
    }

    private var threeCells: [SuggestionBarCell] {
        [
            SuggestionBarCell(text: "Teh", source: .userInput, role: .original, confidence: 1.0),
            SuggestionBarCell(text: "The", source: .deterministicRule, role: .suggestion, confidence: 0.99),
            SuggestionBarCell(text: "Ten", source: .textChecker, role: .suggestion, confidence: 0.96),
        ]
    }

    @Test func threeSuggestionsLight() {
        assertSnapshot(of: bar(state(threeCells, token: "Teh")), size: size,
                       colorScheme: .light, named: "bar_three_light")
    }

    @Test func threeSuggestionsDark() {
        assertSnapshot(of: bar(state(threeCells, token: "Teh")), size: size,
                       colorScheme: .dark, named: "bar_three_dark")
    }

    @Test func singleOriginalOnly() {
        let cells = [SuggestionBarCell(text: "hello", source: .userInput, role: .original, confidence: 1.0)]
        assertSnapshot(of: bar(state(cells, token: "hello")), size: size, named: "bar_single_light")
    }

    @Test func emptyState() {
        assertSnapshot(of: bar(nil), size: size, named: "bar_empty_light")
    }
}
