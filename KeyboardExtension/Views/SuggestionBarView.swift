import SwiftUI

// MARK: - Suggestion Bar

struct SuggestionBarView: View {
    private enum Metrics {
        static let horizontalPadding: CGFloat = 10
        static let rowHeight: CGFloat = 32
        static let fontSize: CGFloat = 18
        static let separatorHeight: CGFloat = 18
        static let separatorBottomPadding: CGFloat = 4
        static let separatorWidth: CGFloat = 10
    }

    let state: SuggestionBarState?
    @ObservedObject var actionHandler: KeyboardActionHandler

    var body: some View {
        HStack(spacing: 0) {
            suggestionCell(
                cell: cell(at: 0),
                action: applyCell(at: 0)
            )

            separator

            suggestionCell(
                cell: cell(at: 1),
                action: applyCell(at: 1)
            )

            separator

            suggestionCell(
                cell: cell(at: 2),
                action: applyCell(at: 2)
            )
        }
        .padding(.horizontal, Metrics.horizontalPadding)
        .frame(height: Metrics.rowHeight)
    }

    // The nearly invisible fill keeps the whole column reliably tappable in
    // SwiftUI; Color.clear looked right but did not hit-test consistently.
    private func suggestionCell(
        cell: SuggestionBarCell?,
        action: @escaping () -> Void
    ) -> some View {
        let isEnabled = cell != nil
        return Button(action: action) {
            Rectangle()
                .fill(Color.white.opacity(0.001))
                .overlay(alignment: .top) {
                    Text(cell?.text ?? "")
                        .font(.system(size: Metrics.fontSize, weight: .medium))
                        .foregroundColor(.primary.opacity(isEnabled ? 0.86 : 0.3))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(SuggestionCellButtonStyle(isEnabled: isEnabled))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .opacity(isEnabled ? 1 : 0.55)
        .disabled(!isEnabled)
    }

    private var separator: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.18))
            .frame(width: 1, height: Metrics.separatorHeight)
            .padding(.bottom, Metrics.separatorBottomPadding)
            .frame(width: Metrics.separatorWidth)
            .frame(maxHeight: .infinity, alignment: .top)
    }

    private func cell(at index: Int) -> SuggestionBarCell? {
        guard let state, state.cells.indices.contains(index) else { return nil }
        return state.cells[index]
    }

    private func applyCell(at index: Int) -> () -> Void {
        {
            guard let cell = cell(at: index) else { return }
            actionHandler.applyCell(cell)
        }
    }
}

// MARK: - Press Feedback

private struct SuggestionCellButtonStyle: ButtonStyle {
    let isEnabled: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && isEnabled ? 0.97 : 1)
            .opacity(configuration.isPressed && isEnabled ? 0.72 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

#Preview("Two Suggestions", traits: .sizeThatFitsLayout) {
    let previewHeight: CGFloat = 28
    let handler = KeyboardActionHandler()

    SuggestionBarView(
        state: SuggestionBarState(
            mode: .currentToken,
            cells: [
                SuggestionBarCell(text: "Teh", source: .userInput, role: .original, confidence: 1.0),
                SuggestionBarCell(text: "The", source: .deterministicRule, role: .suggestion, confidence: 0.99),
                SuggestionBarCell(text: "Ten", source: .textChecker, role: .suggestion, confidence: 0.96)
            ],
            context: SuggestionContext.parse("Teh")!
        ),
        actionHandler: handler
    )
    .frame(height: previewHeight)
    .background(Color(UIColor.systemGroupedBackground))
}
