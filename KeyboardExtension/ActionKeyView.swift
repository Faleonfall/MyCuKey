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
    let isTrackpadEnabled: Bool
    let trackpadAction: ((Int) -> Void)?
    
    init(title: String, systemImage: String? = nil, backgroundColor: Color = Color(UIColor.systemGray4), fontSize: CGFloat = 24, isRepeatable: Bool = false, longPressTitle: String? = nil, longPressAction: (() -> Void)? = nil, isTrackpadEnabled: Bool = false, trackpadAction: ((Int) -> Void)? = nil, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.backgroundColor = backgroundColor
        self.fontSize = fontSize
        self.isRepeatable = isRepeatable
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
            longPressTitle: longPressTitle,
            longPressAction: longPressAction,
            isTrackpadEnabled: isTrackpadEnabled,
            trackpadAction: trackpadAction,
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
    let isTrackpadEnabled: Bool
    let trackpadAction: ((Int) -> Void)?
    let action: () -> Void
    
    @State private var repeatTask: Task<Void, Never>?
    @State private var isLongPressing = false
    @State private var dragStartOffset: CGFloat = 0
    @State private var isDragging = false
    
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
            .trackpadGesture(
                isEnabled: isTrackpadEnabled,
                trackpadAction: trackpadAction,
                isDragging: $isDragging,
                dragStartOffset: $dragStartOffset
            )
            .onChange(of: configuration.isPressed) { oldValue, newValue in
                if newValue {
                    if isTrackpadEnabled {
                        // Trackpad mode executes primarily on touch UP, so do NOTHING on touch DOWN.
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } else if longPressTitle != nil {
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
                    
                    if isTrackpadEnabled {
                        // If we didn't drag, it was a short tap, so we commit the action
                        if !isDragging {
                            action()
                        }
                        // DO NOT reset isDragging here. .highPriorityGesture's .onEnded natively resets it!
                    } else if longPressTitle != nil {
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

// MARK: - Gesture Extension
extension View {
    @ViewBuilder
    func trackpadGesture(isEnabled: Bool, trackpadAction: ((Int)->Void)?, isDragging: Binding<Bool>, dragStartOffset: Binding<CGFloat>) -> some View {
        if isEnabled {
            self.highPriorityGesture(
                DragGesture(minimumDistance: 5)
                    .onChanged { value in
                        if !isDragging.wrappedValue {
                            isDragging.wrappedValue = true
                            dragStartOffset.wrappedValue = value.translation.width
                            HapticFeedback.playMedium() // Trackpad initiate haptic
                        }
                        
                        let translation = value.translation.width
                        let threshold = 12.0 // Pixels per character slice
                        let steps = Int((translation - dragStartOffset.wrappedValue) / threshold)
                        
                        if steps != 0 {
                            trackpadAction?(steps)
                            dragStartOffset.wrappedValue += CGFloat(steps) * threshold
                        }
                    }
                    .onEnded { _ in
                        isDragging.wrappedValue = false
                        dragStartOffset.wrappedValue = 0
                    }
            )
        } else {
            self
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
