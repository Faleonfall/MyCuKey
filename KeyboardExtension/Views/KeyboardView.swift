import SwiftUI

// MARK: - Phase 2 Spatial Capture
let keyboardCoordinateSpaceName = "keyboardSpatial"

// Reports a key's center and the landing point of each tap, both in the shared
// keyboard coordinate space, exactly once per press. Attached only to letter
// keys so action/space/delete gesture handling is never affected.
struct SpatialCaptureModifier: ViewModifier {
    let character: Character
    let onTap: (CGPoint) -> Void
    let onCenter: (Character, CGPoint) -> Void
    @State private var reportedThisPress = false

    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .onAppear { onCenter(character, Self.center(proxy)) }
                        .onChange(of: proxy.frame(in: .named(keyboardCoordinateSpaceName)).minX) {
                            _, _ in
                            onCenter(character, Self.center(proxy))
                        }
                }
            )
            .simultaneousGesture(
                DragGesture(
                    minimumDistance: 0, coordinateSpace: .named(keyboardCoordinateSpaceName)
                )
                .onChanged { value in
                    guard !reportedThisPress else { return }
                    reportedThisPress = true
                    onTap(value.startLocation)
                }
                .onEnded { _ in reportedThisPress = false }
            )
    }

    private static func center(_ proxy: GeometryProxy) -> CGPoint {
        let frame = proxy.frame(in: .named(keyboardCoordinateSpaceName))
        return CGPoint(x: frame.midX, y: frame.midY)
    }
}

extension View {
    @ViewBuilder
    func spatialCapture(
        enabled: Bool,
        character: Character,
        onTap: ((CGPoint) -> Void)?,
        onCenter: ((Character, CGPoint) -> Void)?
    ) -> some View {
        if enabled, let onTap, let onCenter {
            modifier(SpatialCaptureModifier(character: character, onTap: onTap, onCenter: onCenter))
        } else {
            self
        }
    }
}

// MARK: - Keyboard Layout
enum KeyboardLayout {
    static let alphabeticTopRow = ["Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"]
    static let alphabeticMiddleRow = ["A", "S", "D", "F", "G", "H", "J", "K", "L"]
    static let alphabeticBottomRow = ["Z", "X", "C", "V", "B", "N", "M"]

    static let numericTopRow = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]
    static let numericMiddleRow = ["-", "/", ":", ";", "(", ")", "$", "&", "\"", "'"]
    static let sharedBottomCenterRow = [".", "_", "@", "!", "+"]

    static let symbolicTopRow = ["[", "]", "{", "}", "#", "%", "^", "`", "+", "="]
    static let symbolicMiddleRow = ["_", "\\", "|", "~", "<", ">", "€", "£", "¥", "•"]
}

// MARK: - Shared Metrics
enum KeyboardMetrics {
    static let rowHeight: CGFloat = 53
    static let sideKeyWidth: CGFloat = 44
    static let spaceRowSideKeyWidth: CGFloat = 45
    static let bottomRowInset: CGFloat = 16
}

// MARK: - Popup Alignment Helpers
func splitTopRowPopupAlignments(for keys: [String]) -> [String: KeyPopupAlignment] {
    let midpoint = keys.count / 2
    return Dictionary(
        uniqueKeysWithValues: keys.enumerated().map { index, key in
            let alignment: KeyPopupAlignment =
                index < midpoint ? .diagonalFromLeft : .diagonalFromRight
            return (key, alignment)
        })
}

func edgePopupAlignments(leftKey: String, rightKey: String) -> [String: KeyPopupAlignment] {
    [
        leftKey: .insetFromLeft,
        rightKey: .insetFromRight,
    ]
}

private func popupZIndex(for alignment: KeyPopupAlignment, index: Int, count: Int) -> Double {
    switch alignment {
    case .centered:
        return 0
    case .insetFromLeft, .diagonalFromLeft:
        // Left-leaning popups need earlier keys to outrank later neighbors.
        return Double((count - index) + 10)
    case .insetFromRight, .diagonalFromRight:
        // Right-leaning popups need later keys to outrank earlier neighbors.
        return Double(index + 10)
    }
}

// MARK: - Shared Row Views
struct KeyboardRow: View {
    let keys: [String]
    let backgroundColor: Color
    var leadingInset: CGFloat = 0
    var trailingInset: CGFloat = 0
    var popupAlignments: [String: KeyPopupAlignment] = [:]
    var keyTitle: (String) -> String = { $0 }
    var spatialCaptureEnabled: Bool = false
    var onLetterTap: ((CGPoint) -> Void)? = nil
    var onLetterCenter: ((Character, CGPoint) -> Void)? = nil
    let onKeyPress: (String) -> Void

    var body: some View {
        HStack(spacing: 0) {
            if leadingInset > 0 {
                Spacer(minLength: leadingInset)
            }

            ForEach(Array(keys.enumerated()), id: \.element) { index, key in
                let title = keyTitle(key)
                let popupAlignment = popupAlignments[key] ?? .centered
                ActionKeyView(
                    title: title,
                    backgroundColor: backgroundColor,
                    popupAlignment: popupAlignment
                ) {
                    onKeyPress(title)
                }
                .spatialCapture(
                    enabled: spatialCaptureEnabled,
                    character: Character(key.lowercased()),
                    onTap: onLetterTap,
                    onCenter: onLetterCenter
                )
                .zIndex(popupZIndex(for: popupAlignment, index: index, count: keys.count))
            }

            if trailingInset > 0 {
                Spacer(minLength: trailingInset)
            }
        }
        .frame(height: KeyboardMetrics.rowHeight)
    }
}

struct KeyboardDeleteKey: View {
    @ObservedObject var actionHandler: KeyboardActionHandler
    let backgroundColor: Color

    var body: some View {
        ActionKeyView(
            title: "Delete",
            systemImage: "delete.left",
            backgroundColor: backgroundColor,
            isRepeatable: true,
            suppressRepeatHaptic: true,
            acceleratedAction: { actionHandler.deleteWordBackward() }
        ) {
            actionHandler.deleteBackward()
        }
        .frame(width: KeyboardMetrics.sideKeyWidth)
    }
}

struct KeyboardModeKey: View {
    @ObservedObject var actionHandler: KeyboardActionHandler
    let title: String
    let targetMode: KeyboardType
    let backgroundColor: Color

    var body: some View {
        ActionKeyView(title: title, backgroundColor: backgroundColor, fontSize: 16) {
            actionHandler.currentKeyboardType = targetMode
        }
        .frame(width: KeyboardMetrics.sideKeyWidth)
    }
}

struct KeyboardCenteredBottomRow: View {
    let keys: [String]
    let letterKeyBg: Color
    let leadingKey: AnyView
    let trailingKey: AnyView
    var popupAlignments: [String: KeyPopupAlignment] = [:]
    let onKeyPress: (String) -> Void

    var body: some View {
        HStack(spacing: 0) {
            leadingKey
            Spacer(minLength: KeyboardMetrics.bottomRowInset)

            ForEach(Array(keys.enumerated()), id: \.element) { index, key in
                let popupAlignment = popupAlignments[key] ?? .centered
                ActionKeyView(
                    title: key,
                    backgroundColor: letterKeyBg,
                    popupAlignment: popupAlignment
                ) {
                    onKeyPress(key)
                }
                .zIndex(popupZIndex(for: popupAlignment, index: index, count: keys.count))
            }

            Spacer(minLength: KeyboardMetrics.bottomRowInset)
            trailingKey
        }
        .frame(height: KeyboardMetrics.rowHeight)
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
        button.addTarget(
            controller, action: #selector(UIInputViewController.handleInputModeList(from:with:)),
            for: .allTouchEvents)
        return button
    }
    func updateUIView(_ uiView: UIButton, context: Context) {}
}

// MARK: - Main Keyboard View
struct KeyboardView: View {
    @ObservedObject var actionHandler: KeyboardActionHandler
    var needsInputModeSwitchKey: Bool
    var controller: UIInputViewController

    @Environment(\.colorScheme) var colorScheme

    var letterKeyBg: Color {
        colorScheme == .dark ? Color(UIColor.systemGray2) : Color(UIColor.systemBackground)
    }
    var actionKeyBg: Color {
        colorScheme == .dark ? Color(UIColor.systemGray4) : Color(UIColor.systemBackground)
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Keep a stable top strip across all keyboard modes so switching
            // layouts does not change the extension height and cause a jump.
            SuggestionBarView(
                state: actionHandler.currentKeyboardType == .alphabetic
                    ? actionHandler.suggestionBarState : nil,
                actionHandler: actionHandler
            )

            switch actionHandler.currentKeyboardType {
            case .alphabetic:
                AlphabeticKeyboardView(
                    actionHandler: actionHandler,
                    needsInputModeSwitchKey: needsInputModeSwitchKey,
                    controller: controller,
                    letterKeyBg: letterKeyBg,
                    actionKeyBg: actionKeyBg
                )
            case .numeric:
                NumericKeyboardView(
                    actionHandler: actionHandler,
                    needsInputModeSwitchKey: needsInputModeSwitchKey,
                    controller: controller,
                    letterKeyBg: letterKeyBg,
                    actionKeyBg: actionKeyBg
                )
            case .symbolic:
                SymbolicKeyboardView(
                    actionHandler: actionHandler,
                    needsInputModeSwitchKey: needsInputModeSwitchKey,
                    controller: controller,
                    letterKeyBg: letterKeyBg,
                    actionKeyBg: actionKeyBg
                )
            }
        }
        .padding(.horizontal, 3)
        .animation(
            .spring(response: 0.3, dampingFraction: 0.8), value: actionHandler.currentKeyboardType)
    }
}
