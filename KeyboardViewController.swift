import UIKit
import SwiftUI
import Combine

// MARK: - Standard View Controller
class KeyboardViewController: UIInputViewController {
    
    let actionHandler = KeyboardActionHandler()
    private var hostingController: UIHostingController<KeyboardView>?
    private var cancellables = Set<AnyCancellable>()
    private var keyboardHeightConstraint: NSLayoutConstraint?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.actionHandler.controller = self
        self.view.backgroundColor = .clear
        self.inputView?.backgroundColor = .clear
        self.view.clipsToBounds = false
        self.inputView?.clipsToBounds = false

        let keyboardView = KeyboardView(
             actionHandler: actionHandler,
             needsInputModeSwitchKey: self.needsInputModeSwitchKey,
             controller: self
        )
        
        let hc = UIHostingController(rootView: keyboardView)
        hc.view.translatesAutoresizingMaskIntoConstraints = false
        hc.view.backgroundColor = .clear
        hc.view.clipsToBounds = false
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

        let heightConstraint = view.heightAnchor.constraint(equalToConstant: currentKeyboardHeight)
        heightConstraint.priority = .required
        heightConstraint.isActive = true
        keyboardHeightConstraint = heightConstraint
        
        self.hostingController = hc

        Publishers.CombineLatest(actionHandler.$currentKeyboardType, actionHandler.$suggestionBarState)
            .sink { [weak self] _, _ in
                self?.updateKeyboardHeight()
            }
            .store(in: &cancellables)
        
        // Modern iOS 17+ trait change API — replaces deprecated traitCollectionDidChange
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { [weak self] (_: KeyboardViewController, _: UITraitCollection) in
            guard let self else { return }
            self.hostingController?.overrideUserInterfaceStyle = self.traitCollection.userInterfaceStyle
        }
    }
    
    // Maintain properties during dark / light mode switch
    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        
        // Use externalized logic for unit testability
        let contextBefore = textDocumentProxy.documentContextBeforeInput
        self.actionHandler.evaluateAutoCapitalization(contextBefore: contextBefore)
        self.actionHandler.refreshSuggestions(for: contextBefore)
    }

    private var currentKeyboardHeight: CGFloat {
        let baseHeight = KeyboardMetrics.rowHeight * 4.0 + 4.0
        let suggestionHeight = 28.0
        return baseHeight + suggestionHeight
    }

    private func updateKeyboardHeight() {
        keyboardHeightConstraint?.constant = currentKeyboardHeight
        view.layoutIfNeeded()
    }
}

// MARK: - Preview Support

private struct KeyboardPreviewContainer: View {
    private let previewSuggestionHeight: CGFloat = 28
    @StateObject private var handler: KeyboardActionHandler
    private let previewController = UIInputViewController()

    init() {
        let handler = KeyboardActionHandler()
        handler.currentKeyboardType = .alphabetic
        handler.suggestionBarState = SuggestionBarState(
            mode: .currentToken,
            cells: [
                SuggestionBarCell(text: "Teh", source: .userInput, role: .original, confidence: 1.0),
                SuggestionBarCell(text: "The", source: .deterministicRule, role: .suggestion, confidence: 0.99),
                SuggestionBarCell(text: "Ten", source: .textChecker, role: .suggestion, confidence: 0.96)
            ],
            context: SuggestionContext.parse("Teh")!
        )
        _handler = StateObject(wrappedValue: handler)
    }

    var body: some View {
        KeyboardView(
            actionHandler: handler,
            needsInputModeSwitchKey: false,
            controller: previewController
        )
        .frame(height: KeyboardMetrics.rowHeight * 4.0 + previewSuggestionHeight)
        .background(Color(UIColor.systemGroupedBackground))
    }
}

// MARK: - Preview
#Preview("Keyboard With Suggestions", traits: .sizeThatFitsLayout) {
    KeyboardPreviewContainer()
}
