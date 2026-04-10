import UIKit
import SwiftUI
import Combine

// MARK: - Keyboard Action Handler
class KeyboardActionHandler: ObservableObject {
    weak var controller: UIInputViewController?
    @Published var isShiftEnabled: Bool = false
    
    func insertText(_ text: String) {
        controller?.textDocumentProxy.insertText(text)
    }
    
    func deleteBackward() {
        controller?.textDocumentProxy.deleteBackward()
    }
}

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

// MARK: - Keyboard Action Key
struct ActionKeyView: View {
    let title: String
    let systemImage: String?
    let action: () -> Void
    let backgroundColor: Color
    
    init(title: String, systemImage: String? = nil, backgroundColor: Color = Color(UIColor.systemGray4), action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.backgroundColor = backgroundColor
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(backgroundColor)
                    .shadow(color: .black.opacity(0.3), radius: 0, x: 0, y: 1)
                    .animation(nil, value: backgroundColor) // Force instantaneous background snap
                
                if let systemImage = systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 20, weight: .regular))
                        .foregroundColor(.primary)
                        .animation(nil, value: systemImage) // Force instantaneous icon snap
                } else {
                    Text(title)
                        .font(.system(size: 24, weight: .regular))
                        .foregroundColor(.primary)
                        .animation(nil, value: title) // Force instantaneous letter swap
                }
            }
        }
        .buttonStyle(.plain) // Remove SwiftUI's default slow highlight fade
        .frame(minWidth: 26, maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Main Keyboard View
struct KeyboardView: View {
    @ObservedObject var actionHandler: KeyboardActionHandler
    var needsInputModeSwitchKey: Bool
    var controller: UIInputViewController
    
    let topRow = ["Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"]
    let middleRow = ["A", "S", "D", "F", "G", "H", "J", "K", "L"]
    let bottomRow = ["Z", "X", "C", "V", "B", "N", "M"]
    
    var body: some View {
        VStack(spacing: 8) {
            Spacer()
            
            // Top Row
            HStack(spacing: 6) {
                ForEach(topRow, id: \.self) { key in
                    let letter = actionHandler.isShiftEnabled ? key : key.lowercased()
                    ActionKeyView(title: letter, backgroundColor: Color(UIColor.systemBackground)) {
                        actionHandler.insertText(letter)
                        actionHandler.isShiftEnabled = false
                    }
                }
            }
            .frame(height: 45) // <-- Restored explicit height
            
            // Middle Row
            HStack(spacing: 6) {
                Spacer(minLength: 16)
                ForEach(middleRow, id: \.self) { key in
                    let letter = actionHandler.isShiftEnabled ? key : key.lowercased()
                    ActionKeyView(title: letter, backgroundColor: Color(UIColor.systemBackground)) {
                        actionHandler.insertText(letter)
                        actionHandler.isShiftEnabled = false
                    }
                }
                Spacer(minLength: 16)
            }
            .frame(height: 45) // <-- Restored explicit height
            
            // Bottom Row
            HStack(spacing: 6) {
                let shiftBg = actionHandler.isShiftEnabled ? Color(UIColor.systemBackground) : Color(UIColor.systemGray2)
                ActionKeyView(title: "Shift", systemImage: actionHandler.isShiftEnabled ? "shift.fill" : "shift", backgroundColor: shiftBg) { 
                    actionHandler.isShiftEnabled.toggle()
                }
                .frame(width: 38)
                
                ForEach(bottomRow, id: \.self) { key in
                    let letter = actionHandler.isShiftEnabled ? key : key.lowercased()
                    ActionKeyView(title: letter, backgroundColor: Color(UIColor.systemBackground)) {
                        actionHandler.insertText(letter)
                        actionHandler.isShiftEnabled = false
                    }
                }
                
                ActionKeyView(title: "Delete", systemImage: "delete.left", backgroundColor: Color(UIColor.systemGray2)) {
                    actionHandler.deleteBackward()
                }
                .frame(width: 38)
            }
            .frame(height: 45) // <-- Restored explicit height
            
            // Space Row
            HStack(spacing: 10) {
                if needsInputModeSwitchKey {
                    NextKeyboardButton(controller: controller)
                        .frame(width: 60)
                        .frame(maxHeight: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color(UIColor.systemGray2))
                                .shadow(color: .black.opacity(0.3), radius: 0, x: 0, y: 1)
                        )
                } else {
                    ActionKeyView(title: "?123", backgroundColor: Color(UIColor.systemGray2)) { }
                        .frame(width: 60)
                }
                ActionKeyView(title: "", backgroundColor: Color(UIColor.systemBackground)) {
                    actionHandler.insertText(" ")
                }
                
                ActionKeyView(title: "", systemImage: "arrow.right", backgroundColor: Color(UIColor.systemGray2)) {
                    actionHandler.insertText("\n")
                }
                .frame(width: 60)
            }
            .frame(height: 45) // <-- Restored explicit height
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 6)
        .animation(nil, value: actionHandler.isShiftEnabled) // Make shift state changes instantaneous
        // No hardcoded background so it merges with the keyboard's native accessory view perfectly
    }
}

// MARK: - Standard View Controller
class KeyboardViewController: UIInputViewController {
    
    let actionHandler = KeyboardActionHandler()

    override func updateViewConstraints() {
        super.updateViewConstraints()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.actionHandler.controller = self
        
        let keyboardView = KeyboardView(
             actionHandler: actionHandler,
             needsInputModeSwitchKey: self.needsInputModeSwitchKey,
             controller: self
        )
        
        // Wrap the SwiftUI view inside a Hosting Controller
        let hostingController = UIHostingController(rootView: keyboardView)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        hostingController.view.backgroundColor = .clear
        
        self.addChild(hostingController)
        self.view.addSubview(hostingController.view)
        hostingController.didMove(toParent: self)
        
        NSLayoutConstraint.activate([
            hostingController.view.leftAnchor.constraint(equalTo: view.leftAnchor),
            hostingController.view.rightAnchor.constraint(equalTo: view.rightAnchor),
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    // Maintain properties during dark / light mode switch
    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        
        // Auto-capitalization logic
        let contextBefore = textDocumentProxy.documentContextBeforeInput ?? ""
        if contextBefore.isEmpty {
            self.actionHandler.isShiftEnabled = true
        } else if contextBefore.hasSuffix(". ") || contextBefore.hasSuffix("! ") || contextBefore.hasSuffix("? ") || contextBefore.hasSuffix("\n") {
            self.actionHandler.isShiftEnabled = true
        }
    }
}

// MARK: - Preview
#Preview {
    KeyboardView(
        actionHandler: KeyboardActionHandler(),
        needsInputModeSwitchKey: true,
        controller: UIInputViewController()
    )
    .frame(height: 250) // Approximate keyboard height
    .padding(.top, 10)
    .background(Color(UIColor.systemGroupedBackground))
}
