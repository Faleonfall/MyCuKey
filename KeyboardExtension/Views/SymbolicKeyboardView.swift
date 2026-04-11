import SwiftUI

struct SymbolicKeyboardView: View {
    @ObservedObject var actionHandler: KeyboardActionHandler
    var needsInputModeSwitchKey: Bool
    var controller: UIInputViewController
    var letterKeyBg: Color
    var actionKeyBg: Color

    var body: some View {
        VStack(spacing: 0) {
            KeyboardRow(keys: KeyboardLayout.symbolicTopRow, backgroundColor: letterKeyBg) { key in
                actionHandler.insertText(key)
            }

            KeyboardRow(keys: KeyboardLayout.symbolicMiddleRow, backgroundColor: letterKeyBg) { key in
                actionHandler.insertText(key)
            }

            KeyboardCenteredBottomRow(
                keys: KeyboardLayout.sharedBottomCenterRow,
                letterKeyBg: letterKeyBg,
                leadingKey: AnyView(
                    KeyboardModeKey(
                        actionHandler: actionHandler,
                        title: "123",
                        targetMode: .numeric,
                        backgroundColor: actionKeyBg
                    )
                ),
                trailingKey: AnyView(
                    KeyboardDeleteKey(actionHandler: actionHandler, backgroundColor: actionKeyBg)
                )
            ) { key in
                actionHandler.insertText(key)
            }

            SpaceRowView(
                actionHandler: actionHandler,
                needsInputModeSwitchKey: needsInputModeSwitchKey,
                controller: controller,
                mode: .symbolic,
                letterKeyBg: letterKeyBg,
                actionKeyBg: actionKeyBg
            )
        }
    }
}
