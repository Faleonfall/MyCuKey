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
                title: state?.originalToken ?? "",
                action: actionHandler.applyOriginalSuggestion
            )

            separator

            suggestionCell(
                title: firstSuggestion?.text ?? "",
                isEnabled: firstSuggestion != nil,
                action: {
                    if let suggestion = firstSuggestion {
                        actionHandler.applySuggestion(suggestion)
                    }
                }
            )

            separator

            suggestionCell(
                title: secondSuggestion?.text ?? "",
                isEnabled: secondSuggestion != nil,
                action: {
                    if let suggestion = secondSuggestion {
                        actionHandler.applySuggestion(suggestion)
                    }
                }
            )
        }
        .padding(.horizontal, Metrics.horizontalPadding)
        .frame(height: Metrics.rowHeight)
    }

    // The nearly invisible fill keeps the whole column reliably tappable in
    // SwiftUI; Color.clear looked right but did not hit-test consistently.
    private func suggestionCell(
        title: String,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Rectangle()
                .fill(Color.white.opacity(0.001))
                .overlay(alignment: .top) {
                    Text(title)
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

    private var firstSuggestion: AutocorrectionSuggestion? {
        guard let state, !state.suggestions.isEmpty else { return nil }
        return state.suggestions[0]
    }

    private var secondSuggestion: AutocorrectionSuggestion? {
        guard let state, state.suggestions.count > 1 else { return nil }
        return state.suggestions[1]
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
            originalToken: "Teh",
            suggestions: [
                AutocorrectionSuggestion(text: "The", source: .deterministicRule, confidence: 0.99),
                AutocorrectionSuggestion(text: "Ten", source: .textChecker, confidence: 0.96)
            ],
            trailingSuffix: ""
        ),
        actionHandler: handler
    )
    .frame(height: previewHeight)
    .background(Color(UIColor.systemGroupedBackground))
}
