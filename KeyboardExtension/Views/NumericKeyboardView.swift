import SwiftUI

struct NumericKeyboardView: View {
    @ObservedObject var actionHandler: KeyboardActionHandler
    var needsInputModeSwitchKey: Bool
    var controller: UIInputViewController
    var letterKeyBg: Color
    var actionKeyBg: Color
    
    let numTopRow = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]
    let numMiddleRow = ["-", "/", ":", ";", "(", ")", "$", "&", "\"", "'"]
    let numBottomRow = [".", "_", "@", "!", "+"]
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(numTopRow, id: \.self) { key in
                    ActionKeyView(title: key, backgroundColor: letterKeyBg) { actionHandler.insertText(key) }
                }
            }.frame(height: 53)
            
            HStack(spacing: 0) {
                ForEach(numMiddleRow, id: \.self) { key in
                    ActionKeyView(title: key, backgroundColor: letterKeyBg) { actionHandler.insertText(key) }
                }
            }.frame(height: 53)
            
            HStack(spacing: 0) {
                ActionKeyView(title: "#+=", backgroundColor: actionKeyBg, fontSize: 16) { 
                    actionHandler.currentKeyboardType = .symbolic
                }.frame(width: 44)
                
                Spacer(minLength: 16)
                ForEach(numBottomRow, id: \.self) { key in
                    ActionKeyView(title: key, backgroundColor: letterKeyBg) { actionHandler.insertText(key) }
                }
                Spacer(minLength: 16)
                
                ActionKeyView(title: "Delete", systemImage: "delete.left", backgroundColor: actionKeyBg, isRepeatable: true, suppressRepeatHaptic: true, acceleratedAction: { actionHandler.deleteWordBackward() }) {
                    actionHandler.deleteBackward()
                }.frame(width: 44)
            }.frame(height: 53)
            
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
