import SwiftUI

struct AlphabeticKeyboardView: View {
    @ObservedObject var actionHandler: KeyboardActionHandler
    var needsInputModeSwitchKey: Bool
    var controller: UIInputViewController
    var letterKeyBg: Color
    var actionKeyBg: Color
    
    let topRow = ["Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"]
    let middleRow = ["A", "S", "D", "F", "G", "H", "J", "K", "L"]
    let bottomRow = ["Z", "X", "C", "V", "B", "N", "M"]
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(topRow, id: \.self) { key in
                    let letter = actionHandler.isShiftEnabled ? key : key.lowercased()
                    ActionKeyView(title: letter, backgroundColor: letterKeyBg) {
                        actionHandler.typeLetter(letter)
                    }
                }
            }.frame(height: 53)
            
            HStack(spacing: 0) {
                Spacer(minLength: 16)
                ForEach(middleRow, id: \.self) { key in
                    let letter = actionHandler.isShiftEnabled ? key : key.lowercased()
                    ActionKeyView(title: letter, backgroundColor: letterKeyBg) {
                        actionHandler.typeLetter(letter)
                    }
                }
                Spacer(minLength: 16)
            }.frame(height: 53)
            
            HStack(spacing: 0) {
                let shiftBg = actionHandler.isShiftEnabled ? letterKeyBg : actionKeyBg
                let shiftIcon = actionHandler.isCapsLocked ? "capslock.fill" : (actionHandler.isShiftEnabled ? "shift.fill" : "shift")
                
                ActionKeyView(title: "Shift", systemImage: shiftIcon, backgroundColor: shiftBg) { 
                    actionHandler.handleShiftPress()
                }.frame(width: 44)
                
                ForEach(bottomRow, id: \.self) { key in
                    let letter = actionHandler.isShiftEnabled ? key : key.lowercased()
                    ActionKeyView(title: letter, backgroundColor: letterKeyBg) {
                        actionHandler.typeLetter(letter)
                    }
                }
                
                ActionKeyView(title: "Delete", systemImage: "delete.left", backgroundColor: actionKeyBg, isRepeatable: true, suppressRepeatHaptic: true, acceleratedAction: { actionHandler.deleteWordBackward() }) {
                    actionHandler.deleteBackward()
                }.frame(width: 44)
            }.frame(height: 53)
            
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
}
