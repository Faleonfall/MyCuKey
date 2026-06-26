import XCTest

// End-to-end test of the live keyboard extension. `scripts/xc.sh uitest` seeds
// MyCuKey as the only keyboard first, so focusing a field presents it directly.
// (XCUITest has no Swift Testing equivalent, so this stays XCTest.)

final class KeyboardE2EUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testTypingTehAutocorrectsToThe() {
        let app = XCUIApplication()
        // Force English UI so localized labels are predictable on any sim.
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()

        // Reach the text field: Setup Guide -> Manage Learned Words. The row is
        // in a lazy List below the fold, so scroll it into view first.
        let link = app.buttons["Manage Learned Words"].firstMatch
        var scrolls = 0
        while !link.exists && scrolls < 6 {
            app.swipeUp()
            scrolls += 1
        }
        XCTAssertTrue(
            link.waitForExistence(timeout: 3),
            "dictionary link missing. Tree:\n\(app.debugDescription)")
        link.tap()

        let field = app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 3), "custom-word field missing")
        field.tap()

        dismissKeyboardIntroIfPresent(app)

        // The custom keyboard runs in its own process; its on-screen keys live
        // in the extension's element tree, not the host app's.
        let keyboard = XCUIApplication(bundleIdentifier: "com.kvolodymyr.MyCuKey.KeyboardExtension")
        XCTAssertTrue(
            waitForKeyboard(keyboard, refocus: field),
            "keyboard never presented. Tree:\n\(app.debugDescription)")

        // Type "teh" + space on the MyCuKey keys, then read the field back.
        tapLetter(keyboard, "t")
        tapLetter(keyboard, "e")
        tapLetter(keyboard, "h")
        tapButton(keyboard, "key.space")

        let value = (field.value as? String) ?? ""
        XCTAssertTrue(
            value.lowercased().contains("the"),
            "expected autocorrect to 'the', field was '\(value)'")
    }

    // MARK: - Helpers

    // First focus can race the extension's cold launch, so the keys may not be
    // queryable yet. Gate the (potentially hanging) UI query behind `.state`,
    // which reads process status without a snapshot, then re-tap the field each
    // round to nudge the host into (re)presenting the keyboard.
    private func waitForKeyboard(_ keyboard: XCUIApplication, refocus field: XCUIElement) -> Bool {
        for attempt in 0..<8 {
            if keyboard.state == .runningForeground,
               keyboard.buttons.firstMatch.waitForExistence(timeout: 2) {
                return true
            }
            if attempt < 7 { field.tap() }
        }
        return false
    }

    // Letter keys carry their glyph as the label; case follows the shift state
    // (autocap makes the first letter uppercase), so accept either.
    private func tapLetter(_ keyboard: XCUIApplication, _ letter: String) {
        let upper = keyboard.buttons[letter.uppercased()]
        let lower = keyboard.buttons[letter.lowercased()]
        let key = upper.waitForExistence(timeout: 1) ? upper : lower
        XCTAssertTrue(
            key.waitForExistence(timeout: 2),
            "letter '\(letter)' not found. Tree:\n\(keyboard.debugDescription)")
        key.tap()
    }

    private func tapButton(_ keyboard: XCUIApplication, _ identifier: String) {
        let key = keyboard.buttons[identifier]
        XCTAssertTrue(
            key.waitForExistence(timeout: 2),
            "button '\(identifier)' not found. Tree:\n\(keyboard.debugDescription)")
        key.tap()
    }

    private func dismissKeyboardIntroIfPresent(_ app: XCUIApplication) {
        for label in ["Continue", "Weiter"] {
            let button = app.buttons[label]
            if button.waitForExistence(timeout: 1) {
                button.tap()
                return
            }
        }
    }
}
