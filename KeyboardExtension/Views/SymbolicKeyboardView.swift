import SwiftUI

// MARK: - Symbolic Keyboard

struct SymbolicKeyboardView: View {
    @ObservedObject var actionHandler: KeyboardActionHandler
    var needsInputModeSwitchKey: Bool
    var controller: UIInputViewController
    var letterKeyBg: Color
    var actionKeyBg: Color

    private let topRowPopupAlignments = splitTopRowPopupAlignments(for: KeyboardLayout.symbolicTopRow)

    private let middleRowPopupAlignments = edgePopupAlignments(leftKey: "_", rightKey: "•")

    // MARK: - Layout

    var body: some View {
        VStack(spacing: 0) {
            KeyboardRow(
                keys: KeyboardLayout.symbolicTopRow,
                backgroundColor: letterKeyBg,
                popupAlignments: topRowPopupAlignments
            ) { key in
                actionHandler.insertText(key)
            }

            KeyboardRow(
                keys: KeyboardLayout.symbolicMiddleRow,
                backgroundColor: letterKeyBg,
                popupAlignments: middleRowPopupAlignments
            ) { key in
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
