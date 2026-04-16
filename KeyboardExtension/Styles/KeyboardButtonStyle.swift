import SwiftUI

struct KeyboardButtonStyle: ButtonStyle {
    static let longPressPopupDelayNanoseconds: UInt64 = 300_000_000
    static let popupAppearDuration: Double = 0.08
    static let popupDisappearDuration: Double = 0.08
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
    
    @Environment(\.colorScheme) var colorScheme
    @State private var repeatTask: Task<Void, Never>?
    @State private var isLongPressing = false
    @State private var dragStartOffset: CGFloat = 0
    @State private var isDragging = false
    @State private var isVisuallyPressed = false  // Decoupled from isPressed — guaranteed min 80ms display
    @State private var pressedPreviewTitle: String?
    @State private var keyFrameInGlobal: CGRect = .zero

    private var keyFaceColor: Color {
        colorScheme == .light ? Color.white : Color(white: 0.35)
    }

    private var popupHorizontalOffset: CGFloat {
        // Default behavior requested: show popup to the left of the key.
        let defaultOffset: CGFloat = -30
        let oppositeOffset: CGFloat = 30
        let edgePadding: CGFloat = 16
        guard keyFrameInGlobal.width > 0 else { return defaultOffset }

        if keyFrameInGlobal.minX <= edgePadding {
            return oppositeOffset
        }
        return defaultOffset
    }

    private var defaultPreviewTitle: String? {
        Self.defaultPreviewTitle(
            title: title,
            systemImage: systemImage,
            isTrackpadEnabled: isTrackpadEnabled
        )
    }

    static func defaultPreviewTitle(title: String, systemImage: String?, isTrackpadEnabled: Bool) -> String? {
        guard systemImage == nil else { return nil }
        guard !title.isEmpty else { return nil }
        guard !isTrackpadEnabled else { return nil }
        // Keep previews to character-like keys; skip wider action labels (?123, ABC, Shift, etc.).
        guard title.count <= 2 else { return nil }
        return title
    }

    static func popupTitle(
        isLongPressing: Bool,
        longPressTitle: String?,
        defaultPreviewTitle: String?,
        pressedPreviewTitle: String?
    ) -> String? {
        isLongPressing ? longPressTitle : (pressedPreviewTitle ?? defaultPreviewTitle)
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label // The massive invisible touch target box
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .onAppear {
                            keyFrameInGlobal = proxy.frame(in: .global)
                        }
                        .onChange(of: proxy.frame(in: .global)) { _, newValue in
                            keyFrameInGlobal = newValue
                        }
                }
            )
            .overlay(
                ZStack {
                    // Solid Brighter Key Background
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(keyFaceColor)
                    
                    if let systemImage = systemImage {
                        Image(systemName: systemImage)
                            .font(.system(size: 20, weight: .regular))
                            .foregroundColor(.primary.opacity(0.85))
                            .animation(nil, value: systemImage)
                    } else {
                        Text(title)
                            .font(.system(size: fontSize, weight: .regular))
                            // Shift lowercase letters up slightly for optical centering
                            .baselineOffset(title.count == 1 && title == title.lowercased() ? 1.5 : 0)
                            .foregroundColor(.primary.opacity(0.85))
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                            .animation(nil, value: title)
                    }
                    
                    // Highlight on press
                    if isVisuallyPressed {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.white.opacity(0.15))
                    }
                }
                .padding(.horizontal, 3)   // Slightly tighter key spacing
                .padding(.vertical, 5)     // Increased from 4
            )
            .overlay(
                Group {
                    if let popupTitle = Self.popupTitle(
                        isLongPressing: isLongPressing,
                        longPressTitle: longPressTitle,
                        defaultPreviewTitle: defaultPreviewTitle,
                        pressedPreviewTitle: pressedPreviewTitle
                    ),
                       (configuration.isPressed || isLongPressing) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(keyFaceColor)
                            
                            Text(popupTitle)
                                .font(.system(size: 32, weight: .regular))
                                .foregroundColor(.primary)
                        }
                        .frame(width: 50, height: 58)
                        .offset(x: popupHorizontalOffset, y: 0)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.95).combined(with: .opacity),
                            removal: .scale(scale: 0.98).combined(with: .opacity)
                        ))
                        .animation(
                            .easeOut(duration: configuration.isPressed ? Self.popupAppearDuration : Self.popupDisappearDuration),
                            value: isLongPressing
                        )
                        .animation(
                            .easeOut(duration: configuration.isPressed ? Self.popupAppearDuration : Self.popupDisappearDuration),
                            value: configuration.isPressed
                        )
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
                    pressedPreviewTitle = defaultPreviewTitle
                    
                    if isTrackpadEnabled {
                        // Trackpad mode executes primarily on touch UP, so do NOTHING on touch DOWN.
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } else if longPressTitle != nil {
                        // Deferred action required for popup keys
                        HapticFeedback.playLight()
                        repeatTask = Task {
                            try? await Task.sleep(nanoseconds: Self.longPressPopupDelayNanoseconds)
                            if !Task.isCancelled {
                                await MainActor.run {
                                    withAnimation(.easeOut(duration: Self.popupAppearDuration)) {
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
                            withAnimation(.easeOut(duration: Self.popupDisappearDuration)) {
                                isLongPressing = false
                            }
                        } else {
                            // Tapped and released early, commit the primary action
                            action()
                        }
                    }

                    pressedPreviewTitle = nil
                }
            }
    }
}
