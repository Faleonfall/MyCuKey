import SwiftUI

// MARK: - Numeric Keyboard

struct NumericKeyboardView: View {
    @ObservedObject var actionHandler: KeyboardActionHandler
    var needsInputModeSwitchKey: Bool
    var controller: UIInputViewController
    var letterKeyBg: Color
    var actionKeyBg: Color

    private let topRowPopupAlignments = splitTopRowPopupAlignments(for: KeyboardLayout.numericTopRow)

    private let middleRowPopupAlignments = edgePopupAlignments(leftKey: "-", rightKey: "'")

    // MARK: - Layout

    var body: some View {
        VStack(spacing: 0) {
            KeyboardRow(
                keys: KeyboardLayout.numericTopRow,
                backgroundColor: letterKeyBg,
                popupAlignments: topRowPopupAlignments
            ) { key in
                actionHandler.insertText(key)
            }

            KeyboardRow(
                keys: KeyboardLayout.numericMiddleRow,
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
                        title: "#+=",
                        targetMode: .symbolic,
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
                mode: .numeric,
                letterKeyBg: letterKeyBg,
                actionKeyBg: actionKeyBg
            )
        }
    }
}
