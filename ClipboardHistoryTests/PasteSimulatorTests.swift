import XCTest
import Carbon.HIToolbox
@testable import ClipboardHistory

final class PasteSimulatorTests: XCTestCase {
    func testImageInTerminalUsesControlV() {
        let image: ItemContent = .image(filename: "x.png")
        for terminal in PasteSimulator.terminalBundleIDs {
            XCTAssertEqual(
                PasteSimulator.pasteMethod(for: image, bundleID: terminal),
                .controlV,
                "Expected ^V for image in \(terminal)"
            )
        }
    }

    func testTextInTerminalStillUsesCommandV() {
        for terminal in PasteSimulator.terminalBundleIDs {
            XCTAssertEqual(
                PasteSimulator.pasteMethod(for: .text("hi"), bundleID: terminal),
                .commandV,
                "Text paste in \(terminal) should still use ⌘V"
            )
        }
    }

    func testImageInGuiAppUsesCommandV() {
        let image: ItemContent = .image(filename: "x.png")
        for app in ["com.apple.Safari", "com.apple.mail", "com.tinyspeck.slackmacgap", "com.figma.Desktop"] {
            XCTAssertEqual(
                PasteSimulator.pasteMethod(for: image, bundleID: app),
                .commandV,
                "GUI app \(app) should receive ⌘V for images"
            )
        }
    }

    func testFilesNeverUseControlV() {
        let files: ItemContent = .files([URL(fileURLWithPath: "/tmp/a")])
        XCTAssertEqual(PasteSimulator.pasteMethod(for: files, bundleID: "com.apple.Terminal"), .commandV)
    }

    func testEmptyBundleIDUsesCommandV() {
        XCTAssertEqual(PasteSimulator.pasteMethod(for: .image(filename: "x"), bundleID: ""), .commandV)
    }

    func testKnownTerminalsIncludeClaudeCodeHosts() {
        XCTAssertTrue(PasteSimulator.terminalBundleIDs.contains("com.apple.Terminal"))
        XCTAssertTrue(PasteSimulator.terminalBundleIDs.contains("com.googlecode.iterm2"))
        XCTAssertTrue(PasteSimulator.terminalBundleIDs.contains("dev.warp.Warp-Stable"))
        XCTAssertTrue(PasteSimulator.terminalBundleIDs.contains("com.mitchellh.ghostty"))
    }

    // A terminal reading the key through the active layout must still see ^V, so the control
    // character has to travel as the event's text rather than as ⌃ plus the V key.
    func testControlVKeystrokeCarriesControlCharacterWithoutModifiers() {
        let events = PasteSimulator.keystrokeEvents(for: .controlV)
        XCTAssertEqual(events.map(\.type), [.keyDown, .keyUp])

        for event in events {
            XCTAssertEqual(event.getIntegerValueField(.keyboardEventKeycode), Int64(kVK_ANSI_V))
            XCTAssertEqual(event.flags, [])
            XCTAssertEqual(unicodeString(of: event), [0x16])
        }
    }

    func testCommandVKeystrokeCarriesCommandModifier() {
        let events = PasteSimulator.keystrokeEvents(for: .commandV)
        XCTAssertEqual(events.map(\.type), [.keyDown, .keyUp])

        for event in events {
            XCTAssertEqual(event.getIntegerValueField(.keyboardEventKeycode), Int64(kVK_ANSI_V))
            XCTAssertTrue(event.flags.contains(.maskCommand))
            XCTAssertFalse(event.flags.contains(.maskControl))
        }
    }

    // Overriding the event's text breaks ⌘V key equivalent matching, so the command path must leave it alone.
    func testCommandVKeystrokeDoesNotOverrideCharacter() {
        for event in PasteSimulator.keystrokeEvents(for: .commandV) {
            XCTAssertNotEqual(unicodeString(of: event), [0x16])
        }
    }

    private func unicodeString(of event: CGEvent) -> [UniChar] {
        var length = 0
        var buffer = [UniChar](repeating: 0, count: 4)
        event.keyboardGetUnicodeString(maxStringLength: buffer.count, actualStringLength: &length, unicodeString: &buffer)
        return Array(buffer.prefix(length))
    }
}
