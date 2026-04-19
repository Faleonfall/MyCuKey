import SwiftUI

// MARK: - Space Row

struct SpaceRowView: View {
    @ObservedObject var actionHandler: KeyboardActionHandler
    var needsInputModeSwitchKey: Bool
    var controller: UIInputViewController
    var mode: KeyboardType
    var letterKeyBg: Color
    var actionKeyBg: Color

    // MARK: - Layout

    var body: some View {
        HStack(spacing: 0) {
            if needsInputModeSwitchKey {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous).fill(actionKeyBg)
                    NextKeyboardButton(controller: controller)
                }
                .padding(.horizontal, 3)
                .padding(.vertical, 4)
                .frame(width: 60)
            } else {
                let title = mode == .alphabetic ? "?123" : "ABC"
                ActionKeyView(title: title, backgroundColor: actionKeyBg, fontSize: 18) {
                    actionHandler.currentKeyboardType = mode == .alphabetic ? .numeric : .alphabetic
                }
                .frame(width: 60)
            }

            ActionKeyView(
                title: "*",
                backgroundColor: actionKeyBg,
                longPressTitle: "\"",
                longPressAction: { actionHandler.insertText("\"") },
                action: { actionHandler.insertText("*") }
            )
            .frame(width: 45)

            ActionKeyView(
                title: "",
                backgroundColor: letterKeyBg,
                isTrackpadEnabled: true,
                trackpadAction: { steps in
                    // The trackpad surface uses proxy bounds checks so fast scrubbing
                    // does not try to move beyond the text context the host exposes.
                    let proxy = actionHandler.controller?.textDocumentProxy

                    guard proxy?.hasText == true else { return }

                    if steps < 0 && (proxy?.documentContextBeforeInput?.isEmpty ?? true) {
                        return
                    }

                    if steps > 0 && (proxy?.documentContextAfterInput?.isEmpty ?? true) {
                        return
                    }

                    proxy?.adjustTextPosition(byCharacterOffset: steps)
                    HapticFeedback.playLight()
                },
                action: { actionHandler.insertText(" ") }
            )

            ActionKeyView(
                title: ",",
                backgroundColor: actionKeyBg,
                longPressTitle: "?",
                longPressAction: { actionHandler.insertText("?") },
                action: { actionHandler.insertText(",") }
            )
            .frame(width: 45)

            ActionKeyView(title: "", systemImage: "return", backgroundColor: actionKeyBg) {
                actionHandler.insertText("\n")
            }
            .frame(width: 45)
        }
        .frame(height: 53)
    }
}
