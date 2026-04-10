import SwiftUI

// MARK: - Keyboard Action Key
struct ActionKeyView: View {
    let title: String
    let systemImage: String?
    let action: () -> Void
    let backgroundColor: Color
    let fontSize: CGFloat
    let isRepeatable: Bool
    let longPressTitle: String?
    let longPressAction: (() -> Void)?
    
    init(title: String, systemImage: String? = nil, backgroundColor: Color = Color(UIColor.systemGray4), fontSize: CGFloat = 24, isRepeatable: Bool = false, longPressTitle: String? = nil, longPressAction: (() -> Void)? = nil, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.backgroundColor = backgroundColor
        self.fontSize = fontSize
        self.isRepeatable = isRepeatable
        self.longPressTitle = longPressTitle
        self.longPressAction = longPressAction
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
            longPressTitle: longPressTitle,
            longPressAction: longPressAction,
            action: action
        ))
        .frame(minWidth: 26, maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Custom Highly Responsive Button Style
struct KeyboardButtonStyle: ButtonStyle {
    let title: String
    let systemImage: String?
    let backgroundColor: Color
    let fontSize: CGFloat
    let isRepeatable: Bool
    let longPressTitle: String?
    let longPressAction: (() -> Void)?
    let action: () -> Void
    
    @State private var repeatTask: Task<Void, Never>?
    @State private var isLongPressing = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label // The massive invisible touch target box
            .overlay(
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(backgroundColor)
                        .animation(nil, value: backgroundColor)
                    
                    if let systemImage = systemImage {
                        Image(systemName: systemImage)
                            .font(.system(size: 20, weight: .regular))
                            .foregroundColor(.primary)
                            .animation(nil, value: systemImage)
                    } else {
                        Text(title)
                            .font(.system(size: fontSize, weight: .regular))
                            .foregroundColor(.primary)
                            .animation(nil, value: title)
                    }
                    
                    // Dark overlay only covers the visual bounds!
                    if configuration.isPressed {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.black.opacity(0.3))
                    }
                }
                // Shrinks the visual rectangle to create visual gaps
                .padding(.horizontal, 3)
                .padding(.vertical, 4)
                .scaleEffect(configuration.isPressed && !isLongPressing ? 0.95 : 1.0)
                .animation(.interactiveSpring(response: 0.15, dampingFraction: 0.6, blendDuration: 0.1), value: configuration.isPressed)
            )
            .overlay(
                Group {
                    if isLongPressing, let popupTitle = longPressTitle {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(backgroundColor)
                                .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 4)
                            
                            Text(popupTitle)
                                .font(.system(size: 32, weight: .regular))
                                .foregroundColor(.primary)
                        }
                        .frame(width: 50, height: 60)
                        .offset(y: -50)
                    }
                }
            )
            .onChange(of: configuration.isPressed) { oldValue, newValue in
                if newValue {
                    if longPressTitle != nil {
                        // Deferred action required for popup keys
                        HapticFeedback.playLight()
                        repeatTask = Task {
                            try? await Task.sleep(nanoseconds: 350_000_000)
                            if !Task.isCancelled {
                                await MainActor.run {
                                    withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                                        isLongPressing = true
                                    }
                                    HapticFeedback.playMedium()
                                }
                            }
                        }
                    } else {
                        // Fire immediately on touch down for standard keys
                        action()
                        HapticFeedback.playLight()
                        
                        if isRepeatable {
                            repeatTask = Task {
                                // Initial holding delay before rapid-fire starts (0.35s)
                                try? await Task.sleep(nanoseconds: 350_000_000)
                                while !Task.isCancelled {
                                    action()
                                    HapticFeedback.playLight()
                                    try? await Task.sleep(nanoseconds: 100_000_000) // fire every 0.1s
                                }
                            }
                        }
                    }
                } else {
                    // Touch released
                    repeatTask?.cancel()
                    repeatTask = nil
                    
                    if longPressTitle != nil {
                        if isLongPressing {
                            // Commit the long press action
                            longPressAction?()
                            withAnimation(.easeOut(duration: 0.15)) {
                                isLongPressing = false
                            }
                        } else {
                            // Tapped and released early, commit the primary action
                            action()
                        }
                    }
                }
            }
    }
}

// MARK: - Haptic Manager
struct HapticFeedback {
    static let light = UIImpactFeedbackGenerator(style: .light)
    static let medium = UIImpactFeedbackGenerator(style: .medium)
    
    static func playLight() {
        light.prepare()
        light.impactOccurred()
    }
    
    static func playMedium() {
        medium.prepare()
        medium.impactOccurred()
    }
}
