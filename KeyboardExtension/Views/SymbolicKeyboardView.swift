import SwiftUI

struct SymbolicKeyboardView: View {
    @ObservedObject var actionHandler: KeyboardActionHandler
    var needsInputModeSwitchKey: Bool
    var controller: UIInputViewController
    var letterKeyBg: Color
    var actionKeyBg: Color
    
    let symTopRow = ["[", "]", "{", "}", "#", "%", "^", "`", "+", "="]
    let symMiddleRow = ["_", "\\", "|", "~", "<", ">", "€", "£", "¥", "•"]
    let numBottomRow = [".", "_", "@", "!", "+"]
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(symTopRow, id: \.self) { key in
                    ActionKeyView(title: key, backgroundColor: letterKeyBg) { actionHandler.insertText(key) }
                }
            }.frame(height: 53)
            
            HStack(spacing: 0) {
                ForEach(symMiddleRow, id: \.self) { key in
                    ActionKeyView(title: key, backgroundColor: letterKeyBg) { actionHandler.insertText(key) }
                }
            }.frame(height: 53)
            
            HStack(spacing: 0) {
                ActionKeyView(title: "123", backgroundColor: actionKeyBg, fontSize: 16) { 
                    actionHandler.currentKeyboardType = .numeric
                }.frame(width: 44)
                
                Spacer(minLength: 16)
                ForEach(numBottomRow, id: \.self) { key in
                    ActionKeyView(title: key, backgroundColor: letterKeyBg) { actionHandler.insertText(key) }
                }
                Spacer(minLength: 16)
                
                ActionKeyView(title: "Delete", systemImage: "delete.left", backgroundColor: actionKeyBg, isRepeatable: true) {
                    actionHandler.deleteBackward()
                }.frame(width: 44)
            }.frame(height: 53)
            
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
