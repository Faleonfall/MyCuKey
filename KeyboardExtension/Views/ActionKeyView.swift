import SwiftUI

// MARK: - Keyboard Action Key
struct ActionKeyView: View {
    let title: String
    let systemImage: String?
    let action: () -> Void
    let backgroundColor: Color
    let fontSize: CGFloat
    let isRepeatable: Bool
    let suppressRepeatHaptic: Bool
    let acceleratedAction: (() -> Void)?
    let longPressTitle: String?
    let longPressAction: (() -> Void)?
    let isTrackpadEnabled: Bool
    let trackpadAction: ((Int) -> Void)?
    
    init(title: String, systemImage: String? = nil, backgroundColor: Color = Color(UIColor.systemGray4), fontSize: CGFloat = 24, isRepeatable: Bool = false, suppressRepeatHaptic: Bool = false, acceleratedAction: (() -> Void)? = nil, longPressTitle: String? = nil, longPressAction: (() -> Void)? = nil, isTrackpadEnabled: Bool = false, trackpadAction: ((Int) -> Void)? = nil, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.backgroundColor = backgroundColor
        self.fontSize = fontSize
        self.isRepeatable = isRepeatable
        self.suppressRepeatHaptic = suppressRepeatHaptic
        self.acceleratedAction = acceleratedAction
        self.longPressTitle = longPressTitle
        self.longPressAction = longPressAction
        self.isTrackpadEnabled = isTrackpadEnabled
        self.trackpadAction = trackpadAction
        self.action = action
    }
    
    var body: some View {
        Button(action: {}) { // Empty action! Style handles execution instantly on press.
            Color.white.opacity(0.001) // Massive invisible touch target that completely fills padding gaps!
        }
        .buttonStyle(KeyboardButtonStyle(
            title: title, 
            systemImage: systemImage, 
            backgroundColor: backgroundColor, 
            fontSize: fontSize,
            isRepeatable: isRepeatable,
            suppressRepeatHaptic: suppressRepeatHaptic,
            acceleratedAction: acceleratedAction,
            longPressTitle: longPressTitle,
            longPressAction: longPressAction,
            isTrackpadEnabled: isTrackpadEnabled,
            trackpadAction: trackpadAction,
            action: action
        ))
        .frame(minWidth: 26, maxWidth: .infinity, maxHeight: .infinity)
    }
}
