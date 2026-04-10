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
    
    let topRow = ["Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"]
    let middleRow = ["A", "S", "D", "F", "G", "H", "J", "K", "L"]
    let bottomRow = ["Z", "X", "C", "V", "B", "N", "M"]
    
    @Environment(\.colorScheme) var colorScheme
    
    var letterKeyBg: Color {
        colorScheme == .dark ? Color(UIColor.systemGray2) : Color(UIColor.systemBackground)
    }
    
    var actionKeyBg: Color {
        colorScheme == .dark ? Color(UIColor.systemGray4) : Color(UIColor.systemGray2)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Top Row
            HStack(spacing: 0) {
                ForEach(topRow, id: \.self) { key in
                    let letter = actionHandler.isShiftEnabled ? key : key.lowercased()
                    ActionKeyView(title: letter, backgroundColor: letterKeyBg) {
                        actionHandler.insertText(letter)
                        actionHandler.isShiftEnabled = false
                    }
                }
            }
            .frame(height: 53) // Restored explicit height + 8px vertical padding compensation
            
            // Middle Row
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
            }
            .frame(height: 53)
            
            // Bottom Row
            HStack(spacing: 0) {
                let shiftBg = actionHandler.isShiftEnabled ? letterKeyBg : actionKeyBg
                ActionKeyView(title: "Shift", systemImage: actionHandler.isShiftEnabled ? "shift.fill" : "shift", backgroundColor: shiftBg) { 
                    actionHandler.isShiftEnabled.toggle()
                }
                .frame(width: 44) // 38 + 6px padding compensation
                
                ForEach(bottomRow, id: \.self) { key in
                    let letter = actionHandler.isShiftEnabled ? key : key.lowercased()
                    ActionKeyView(title: letter, backgroundColor: letterKeyBg) {
                        actionHandler.insertText(letter)
                        actionHandler.isShiftEnabled = false
                    }
                }
                
                ActionKeyView(title: "Delete", systemImage: "delete.left", backgroundColor: actionKeyBg, isRepeatable: true) {
                    actionHandler.deleteBackward()
                }
                .frame(width: 44)
            }
            .frame(height: 53)
            
            // Space Row
            HStack(spacing: 0) {
                if needsInputModeSwitchKey {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(actionKeyBg)
                        NextKeyboardButton(controller: controller)
                    }
                    .padding(.horizontal, 3)
                    .padding(.vertical, 4)
                    .frame(width: 60)
                } else {
                    ActionKeyView(title: "?123", backgroundColor: actionKeyBg, fontSize: 18) { }
                        .frame(width: 60)
                }
                ActionKeyView(title: "", backgroundColor: letterKeyBg) {
                    actionHandler.insertText(" ")
                }
                
                ActionKeyView(title: "*", backgroundColor: actionKeyBg) {
                    actionHandler.insertText("*")
                }
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
        .padding(.horizontal, 4)
        .padding(.vertical, 6)
        .animation(nil, value: actionHandler.isShiftEnabled) // Make shift state changes instantaneous
        // No hardcoded background so it merges with the keyboard's native accessory view perfectly
    }
}
