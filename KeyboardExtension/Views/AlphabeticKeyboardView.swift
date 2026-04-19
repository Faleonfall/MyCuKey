import SwiftUI

// MARK: - Alphabetic Keyboard

struct AlphabeticKeyboardView: View {
    @ObservedObject var actionHandler: KeyboardActionHandler
    var needsInputModeSwitchKey: Bool
    var controller: UIInputViewController
    var letterKeyBg: Color
    var actionKeyBg: Color

    private let topRowPopupAlignments = splitTopRowPopupAlignments(for: KeyboardLayout.alphabeticTopRow)

    // MARK: - Layout

    var body: some View {
        VStack(spacing: 0) {
            KeyboardRow(
                keys: KeyboardLayout.alphabeticTopRow,
                backgroundColor: letterKeyBg,
                popupAlignments: topRowPopupAlignments,
                keyTitle: displayedLetter(for:)
            ) { letter in
                actionHandler.typeLetter(letter)
            }

            KeyboardRow(
                keys: KeyboardLayout.alphabeticMiddleRow,
                backgroundColor: letterKeyBg,
                leadingInset: KeyboardMetrics.bottomRowInset,
                trailingInset: KeyboardMetrics.bottomRowInset,
                keyTitle: displayedLetter(for:)
            ) { letter in
                actionHandler.typeLetter(letter)
            }

            HStack(spacing: 0) {
                let shiftBg = actionHandler.isShiftEnabled ? letterKeyBg : actionKeyBg
                let shiftIcon = actionHandler.isCapsLocked ? "capslock.fill" : (actionHandler.isShiftEnabled ? "shift.fill" : "shift")

                ActionKeyView(title: "Shift", systemImage: shiftIcon, backgroundColor: shiftBg) {
                    actionHandler.handleShiftPress()
                }
                .frame(width: KeyboardMetrics.sideKeyWidth)

                ForEach(KeyboardLayout.alphabeticBottomRow, id: \.self) { key in
                    let letter = displayedLetter(for: key)
                    ActionKeyView(title: letter, backgroundColor: letterKeyBg) {
                        actionHandler.typeLetter(letter)
                    }
                }

                KeyboardDeleteKey(actionHandler: actionHandler, backgroundColor: actionKeyBg)
            }
            .frame(height: KeyboardMetrics.rowHeight)
            
            SpaceRowView(
                actionHandler: actionHandler,
                needsInputModeSwitchKey: needsInputModeSwitchKey,
                controller: controller,
                mode: .alphabetic,
                letterKeyBg: letterKeyBg,
                actionKeyBg: actionKeyBg
            )
        }
    }

    // MARK: - Display

    private func displayedLetter(for key: String) -> String {
        actionHandler.isShiftEnabled ? key : key.lowercased()
    }
}
