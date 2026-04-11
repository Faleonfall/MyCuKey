import UIKit
import SwiftUI
import Combine


// MARK: - Standard View Controller
class KeyboardViewController: UIInputViewController {
    
    let actionHandler = KeyboardActionHandler()
    private var hostingController: UIHostingController<KeyboardView>?

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
        let hc = UIHostingController(rootView: keyboardView)
        hc.view.translatesAutoresizingMaskIntoConstraints = false
        hc.view.backgroundColor = .clear
        
        // Pre-seed the correct color scheme BEFORE the view is added to the hierarchy.
        // This kills the flash — the first render already uses the right colors.
        hc.overrideUserInterfaceStyle = traitCollection.userInterfaceStyle
        
        self.addChild(hc)
        self.view.addSubview(hc.view)
        hc.didMove(toParent: self)
        
        NSLayoutConstraint.activate([
            hc.view.leftAnchor.constraint(equalTo: view.leftAnchor),
            hc.view.rightAnchor.constraint(equalTo: view.rightAnchor),
            hc.view.topAnchor.constraint(equalTo: view.topAnchor),
            hc.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        self.hostingController = hc
        
        // Modern iOS 17+ trait change API — replaces deprecated traitCollectionDidChange
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { [weak self] (_: KeyboardViewController, _: UITraitCollection) in
            guard let self else { return }
            UIView.animate(withDuration: 0.2) {
                self.hostingController?.overrideUserInterfaceStyle = self.traitCollection.userInterfaceStyle
            }
        }
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
