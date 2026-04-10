import UIKit
import SwiftUI
import Combine


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
        
        // Use externalized logic for unit testability
        let contextBefore = textDocumentProxy.documentContextBeforeInput
        self.actionHandler.evaluateAutoCapitalization(contextBefore: contextBefore)
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
