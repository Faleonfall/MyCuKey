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
                AlphabeticKeyboardView(
                    actionHandler: actionHandler, 
                    needsInputModeSwitchKey: needsInputModeSwitchKey, 
                    controller: controller, 
                    letterKeyBg: letterKeyBg, 
                    actionKeyBg: actionKeyBg
                )
            case .numeric:
                NumericKeyboardView(
                    actionHandler: actionHandler, 
                    needsInputModeSwitchKey: needsInputModeSwitchKey, 
                    controller: controller, 
                    letterKeyBg: letterKeyBg, 
                    actionKeyBg: actionKeyBg
                )
            case .symbolic:
                SymbolicKeyboardView(
                    actionHandler: actionHandler, 
                    needsInputModeSwitchKey: needsInputModeSwitchKey, 
                    controller: controller, 
                    letterKeyBg: letterKeyBg, 
                    actionKeyBg: actionKeyBg
                )
            }
        }
        .padding(.horizontal, 4)
        .animation(nil, value: actionHandler.isShiftEnabled)
    }
}
