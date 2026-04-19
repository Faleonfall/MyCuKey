import Testing
@testable import MyCuKey

// MARK: - Keyboard Button Style Tests

@MainActor
struct KeyboardButtonStyleTests {
    // MARK: - Popup Preview Logic

    @Test func testDefaultPreviewShownForSingleLetterKey() async throws {
        let title = KeyboardButtonStyle.defaultPreviewTitle(
            title: "a",
            systemImage: nil,
            isTrackpadEnabled: false
        )
        #expect(title == "a")
    }

    @Test func testDefaultPreviewShownForPunctuationKey() async throws {
        let title = KeyboardButtonStyle.defaultPreviewTitle(
            title: ",",
            systemImage: nil,
            isTrackpadEnabled: false
        )
        #expect(title == ",")
    }

    @Test func testDefaultPreviewHiddenForActionLabel() async throws {
        let title = KeyboardButtonStyle.defaultPreviewTitle(
            title: "Shift",
            systemImage: nil,
            isTrackpadEnabled: false
        )
        #expect(title == nil)
    }

    @Test func testDefaultPreviewHiddenForSystemImageKeys() async throws {
        let title = KeyboardButtonStyle.defaultPreviewTitle(
            title: "Delete",
            systemImage: "delete.left",
            isTrackpadEnabled: false
        )
        #expect(title == nil)
    }

    @Test func testDefaultPreviewHiddenForTrackpadSpacebar() async throws {
        let title = KeyboardButtonStyle.defaultPreviewTitle(
            title: "",
            systemImage: nil,
            isTrackpadEnabled: true
        )
        #expect(title == nil)
    }

    @Test func testPopupTitleUsesDefaultWhenNotLongPressing() async throws {
        let popup = KeyboardButtonStyle.popupTitle(
            isLongPressing: false,
            longPressTitle: "?",
            defaultPreviewTitle: ",",
            pressedPreviewTitle: nil
        )
        #expect(popup == ",")
    }

    @Test func testPopupTitleUsesLongPressVariantWhenActive() async throws {
        let popup = KeyboardButtonStyle.popupTitle(
            isLongPressing: true,
            longPressTitle: "?",
            defaultPreviewTitle: ",",
            pressedPreviewTitle: ","
        )
        #expect(popup == "?")
    }

    @Test func testPopupTitleUsesPressedPreviewToAvoidCasingFlip() async throws {
        let popup = KeyboardButtonStyle.popupTitle(
            isLongPressing: false,
            longPressTitle: "?",
            defaultPreviewTitle: "a",
            pressedPreviewTitle: "A"
        )
        #expect(popup == "A")
    }

    @Test func testPopupLongPressDelayConstant() async throws {
        #expect(KeyboardButtonStyle.longPressPopupDelayNanoseconds == 300_000_000)
    }

    // MARK: - Popup Alignment Helpers

    @Test func testSplitTopRowPopupAlignmentsSplitsLeftAndRightHalves() async throws {
        let alignments = splitTopRowPopupAlignments(for: KeyboardLayout.alphabeticTopRow)

        #expect(alignments["Q"] == .diagonalFromLeft)
        #expect(alignments["T"] == .diagonalFromLeft)
        #expect(alignments["Y"] == .diagonalFromRight)
        #expect(alignments["P"] == .diagonalFromRight)
        #expect(alignments.count == KeyboardLayout.alphabeticTopRow.count)
    }

    @Test func testEdgePopupAlignmentsOnlyMarksExplicitEdgeKeys() async throws {
        let alignments = edgePopupAlignments(leftKey: "-", rightKey: "'")

        #expect(alignments["-"] == .insetFromLeft)
        #expect(alignments["'"] == .insetFromRight)
        #expect(alignments.count == 2)
    }
}
