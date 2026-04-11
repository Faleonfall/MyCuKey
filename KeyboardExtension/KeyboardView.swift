import SwiftUI

// MARK: - Next Keyboard Button Wrapper
struct NextKeyboardButton: UIViewRepresentable {
    var controller: UIInputViewController
    
    func makeUIView(context: Context) -> UIButton {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 22, weight: .light)
        button.setImage(UIImage(systemName: "globe", withConfiguration: config), for: .normal)
        button.tintColor = .label
        button.addTarget(controller, action: #selector(UIInputViewController.handleInputModeList(from:with:)), for: .allTouchEvents)
        return button
    }
    func updateUIView(_ uiView: UIButton, context: Context) {}
}

// MARK: - Main Keyboard View
struct KeyboardView: View {
    @ObservedObject var actionHandler: KeyboardActionHandler
    var needsInputModeSwitchKey: Bool
    var controller: UIInputViewController
    
    // Arrays
    let topRow = ["Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"]
    let middleRow = ["A", "S", "D", "F", "G", "H", "J", "K", "L"]
    let bottomRow = ["Z", "X", "C", "V", "B", "N", "M"]
    
    let numTopRow = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]
    let numMiddleRow = ["-", "/", ":", ";", "(", ")", "$", "&", "\"", "'"]
    let numBottomRow = [".", "_", "@", "!", "+"]
    
    let symTopRow = ["[", "]", "{", "}", "#", "%", "^", "`", "+", "="]
    let symMiddleRow = ["_", "\\", "|", "~", "<", ">", "€", "£", "¥", "•"]
    
    @Environment(\.colorScheme) var colorScheme
    
    var letterKeyBg: Color { colorScheme == .dark ? Color(UIColor.systemGray2) : Color(UIColor.systemBackground) }
    var actionKeyBg: Color { colorScheme == .dark ? Color(UIColor.systemGray4) : Color(UIColor.systemGray2) }
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            switch actionHandler.currentKeyboardType {
            case .alphabetic:
                alphabeticKeyboard
            case .numeric:
                numericKeyboard
            case .symbolic:
                symbolicKeyboard
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 6)
        .animation(nil, value: actionHandler.isShiftEnabled)
    }
    
    // MARK: - Alphabetic View
    @ViewBuilder
    var alphabeticKeyboard: some View {
        HStack(spacing: 0) {
            ForEach(topRow, id: \.self) { key in
                let letter = actionHandler.isShiftEnabled ? key : key.lowercased()
                ActionKeyView(title: letter, backgroundColor: letterKeyBg) {
                    actionHandler.insertText(letter)
                    actionHandler.isShiftEnabled = false
                }
            }
        }.frame(height: 53)
        
        HStack(spacing: 0) {
            Spacer(minLength: 16)
            ForEach(middleRow, id: \.self) { key in
                let letter = actionHandler.isShiftEnabled ? key : key.lowercased()
                ActionKeyView(title: letter, backgroundColor: letterKeyBg) {
                    actionHandler.insertText(letter)
                    actionHandler.isShiftEnabled = false
                }
            }
            Spacer(minLength: 16)
        }.frame(height: 53)
        
        HStack(spacing: 0) {
            let shiftBg = actionHandler.isShiftEnabled ? letterKeyBg : actionKeyBg
            ActionKeyView(title: "Shift", systemImage: actionHandler.isShiftEnabled ? "shift.fill" : "shift", backgroundColor: shiftBg) { 
                actionHandler.isShiftEnabled.toggle()
            }.frame(width: 44)
            
            ForEach(bottomRow, id: \.self) { key in
                let letter = actionHandler.isShiftEnabled ? key : key.lowercased()
                ActionKeyView(title: letter, backgroundColor: letterKeyBg) {
                    actionHandler.insertText(letter)
                    actionHandler.isShiftEnabled = false
                }
            }
            
            ActionKeyView(title: "Delete", systemImage: "delete.left", backgroundColor: actionKeyBg, isRepeatable: true) {
                actionHandler.deleteBackward()
            }.frame(width: 44)
        }.frame(height: 53)
        
        spaceRow(mode: .alphabetic)
    }
    
    // MARK: - Numeric View
    @ViewBuilder
    var numericKeyboard: some View {
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
            
            ActionKeyView(title: "Delete", systemImage: "delete.left", backgroundColor: actionKeyBg, isRepeatable: true) {
                actionHandler.deleteBackward()
            }.frame(width: 44)
        }.frame(height: 53)
        
        spaceRow(mode: .numeric)
    }
    
    // MARK: - Symbolic View
    @ViewBuilder
    var symbolicKeyboard: some View {
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
        
        spaceRow(mode: .symbolic)
    }
    
    // MARK: - Space Row Function
    @ViewBuilder
    func spaceRow(mode: KeyboardType) -> some View {
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
                title: "", 
                backgroundColor: letterKeyBg,
                isTrackpadEnabled: true,
                trackpadAction: { steps in
                    let proxy = actionHandler.controller?.textDocumentProxy
                    
                    // Kill movement if field is perfectly empty
                    guard proxy?.hasText == true else { return }
                    
                    // Stop left-bound bleeding
                    if steps < 0 && (proxy?.documentContextBeforeInput?.isEmpty ?? true) {
                        return
                    }
                    
                    // Stop right-bound bleeding
                    if steps > 0 && (proxy?.documentContextAfterInput?.isEmpty ?? true) {
                        return
                    }
                    
                    // Authorized physically bounded transaction!
                    proxy?.adjustTextPosition(byCharacterOffset: steps)
                    HapticFeedback.playLight()
                },
                action: { actionHandler.insertText(" ") }
            )
            
            ActionKeyView(title: "*", backgroundColor: actionKeyBg) { actionHandler.insertText("*") }
            .frame(width: 45)
            
            ActionKeyView(
                title: ",", 
                backgroundColor: actionKeyBg,
                longPressTitle: "?",
                longPressAction: { actionHandler.insertText("?") },
                action: { actionHandler.insertText(",") }
            )
            .frame(width: 45)
        }
        .frame(height: 53)
    }
}
