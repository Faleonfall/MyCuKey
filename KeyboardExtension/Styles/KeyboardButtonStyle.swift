import SwiftUI

// MARK: - Keyboard Button Style

enum KeyPopupAlignment {
    case centered
    case insetFromLeft
    case insetFromRight
    case diagonalFromLeft
    case diagonalFromRight
}

struct KeyboardButtonStyle: ButtonStyle {
    private enum Metrics {
        static let horizontalInset: CGFloat = 3
        static let verticalInset: CGFloat = 5
        static let popupWidth: CGFloat = 42
        static let popupHeight: CGFloat = 50
        static let popupVerticalOffset: CGFloat = -34
        static let insetSlide: CGFloat = 18
        static let diagonalSlide: CGFloat = 22
        static let keyCornerRadius: CGFloat = 10
        static let popupCornerRadius: CGFloat = 10
    }

    static let longPressPopupDelayNanoseconds: UInt64 = 300_000_000
    static let popupAppearDuration: Double = 0.08
    static let popupDisappearDuration: Double = 0.08
    let title: String
    let systemImage: String?
    let backgroundColor: Color
    let fontSize: CGFloat
    let isRepeatable: Bool
    let suppressRepeatHaptic: Bool
    // Held repeat keys can switch to a word-level action after the initial key-repeat phase.
    let acceleratedAction: (() -> Void)?
    let longPressTitle: String?
    let longPressAction: (() -> Void)?
    let isTrackpadEnabled: Bool
    let trackpadAction: ((Int) -> Void)?
    let popupAlignment: KeyPopupAlignment
    let action: () -> Void
    
    @Environment(\.colorScheme) var colorScheme
    @State private var repeatTask: Task<Void, Never>?
    @State private var isLongPressing = false
    @State private var dragStartOffset: CGFloat = 0
    @State private var isTrackpadTouchActive = false
    @State private var isDragging = false
    // Keep the flash visible long enough to read even on extremely quick taps.
    @State private var isVisuallyPressed = false
    @State private var pressedPreviewTitle: String?

    private var keyFaceColor: Color {
        backgroundColor
    }

    private var pressedOverlayColor: Color {
        colorScheme == .light ? Color.black.opacity(0.06) : Color.white.opacity(0.15)
    }

    private var isTrackpadVisuallyActive: Bool {
        isTrackpadTouchActive || isDragging
    }

    private var popupHorizontalOffset: CGFloat {
        switch popupAlignment {
        case .centered:
            return 0
        case .insetFromLeft:
            return Metrics.insetSlide
        case .insetFromRight:
            return -Metrics.insetSlide
        case .diagonalFromLeft:
            return Metrics.diagonalSlide
        case .diagonalFromRight:
            return -Metrics.diagonalSlide
        }
    }

    private var popupVerticalOffset: CGFloat {
        Metrics.popupVerticalOffset
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

    // MARK: - Button Rendering

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .overlay(
                ZStack {
                    RoundedRectangle(cornerRadius: Metrics.keyCornerRadius, style: .continuous)
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
                    if isVisuallyPressed || isTrackpadVisuallyActive {
                        RoundedRectangle(cornerRadius: Metrics.keyCornerRadius, style: .continuous)
                            .fill(pressedOverlayColor)
                    }
                }
                .padding(.horizontal, Metrics.horizontalInset)
                .padding(.vertical, Metrics.verticalInset)
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
                            RoundedRectangle(cornerRadius: Metrics.popupCornerRadius, style: .continuous)
                                .fill(keyFaceColor)
                                .shadow(color: Color.black.opacity(colorScheme == .light ? 0.14 : 0.3), radius: 2, x: 0, y: 1)
                            
                            Text(popupTitle)
                                .font(.system(size: 32, weight: .regular))
                                .baselineOffset(
                                    popupTitle.count == 1 && popupTitle == popupTitle.lowercased() ? 5 : 0
                                )
                                .foregroundColor(.primary)
                        }
                        .frame(width: Metrics.popupWidth, height: Metrics.popupHeight)
                        .offset(x: popupHorizontalOffset, y: popupVerticalOffset)
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
                        .allowsHitTesting(false)
                    }
                }
            )
            .trackpadGesture(
                isEnabled: isTrackpadEnabled,
                trackpadAction: trackpadAction,
                isTouchActive: $isTrackpadTouchActive,
                isDragging: $isDragging,
                dragStartOffset: $dragStartOffset
            )
            .onChange(of: configuration.isPressed) { oldValue, newValue in
                if newValue {
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
