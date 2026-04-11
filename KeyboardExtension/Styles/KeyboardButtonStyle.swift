import SwiftUI

struct KeyboardButtonStyle: ButtonStyle {
    let title: String
    let systemImage: String?
    let backgroundColor: Color
    let fontSize: CGFloat
    let isRepeatable: Bool
    let suppressRepeatHaptic: Bool
    let acceleratedAction: (() -> Void)?  // Called instead of action after ~1s of holding
    let longPressTitle: String?
    let longPressAction: (() -> Void)?
    let isTrackpadEnabled: Bool
    let trackpadAction: ((Int) -> Void)?
    let action: () -> Void
    
    @State private var repeatTask: Task<Void, Never>?
    @State private var isLongPressing = false
    @State private var dragStartOffset: CGFloat = 0
    @State private var isDragging = false
    @State private var isVisuallyPressed = false  // Decoupled from isPressed — guaranteed min 80ms display
    
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
                    
                    // Dark overlay: driven by isVisuallyPressed, NOT configuration.isPressed
                    if isVisuallyPressed {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.black.opacity(0.3))
                    }
                }
                .padding(.horizontal, 3)
                .padding(.vertical, 4)
                .scaleEffect(isVisuallyPressed && !isLongPressing ? 0.95 : 1.0)
                .animation(.interactiveSpring(response: 0.06, dampingFraction: 0.7, blendDuration: 0.03), value: isVisuallyPressed)
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
                    // Guaranteed minimum visual feedback — shows even on fastest taps
                    isVisuallyPressed = true
                    
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
                                var ticks = 0
                                while !Task.isCancelled {
                                    ticks += 1
                                    // After 10 ticks (~1s), switch to accelerated word-level action
                                    if ticks > 10, let accelerated = acceleratedAction {
                                        accelerated()
                                    } else {
                                        action()
                                    }
                                    if !suppressRepeatHaptic { HapticFeedback.playLight() }
                                    try? await Task.sleep(nanoseconds: 100_000_000) // fire every 0.1s
                                }
                            }
                        }
                    }
                } else {
                    // Touch released
                    repeatTask?.cancel()
                    repeatTask = nil
                    
                    // Guarantee visual press is visible for at least 80ms even on fastest taps
                    Task {
                        try? await Task.sleep(nanoseconds: 35_000_000) // 35ms minimum flash
                        await MainActor.run { isVisuallyPressed = false }
                    }
                    
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
