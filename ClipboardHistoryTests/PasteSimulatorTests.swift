import XCTest
@testable import ClipboardHistory

final class PasteSimulatorTests: XCTestCase {
    func testImageInTerminalUsesControl() {
        let image: ItemContent = .image(filename: "x.png")
        for terminal in PasteSimulator.terminalBundleIDs {
            XCTAssertTrue(
                PasteSimulator.shouldUseControlKey(for: image, bundleID: terminal),
                "Expected Ctrl+V for image in \(terminal)"
            )
        }
    }

    func testTextInTerminalStillUsesCommand() {
        for terminal in PasteSimulator.terminalBundleIDs {
            XCTAssertFalse(
                PasteSimulator.shouldUseControlKey(for: .text("hi"), bundleID: terminal),
                "Text paste in \(terminal) should still use ⌘V"
            )
        }
    }

    func testImageInGuiAppUsesCommand() {
        let image: ItemContent = .image(filename: "x.png")
        for app in ["com.apple.Safari", "com.apple.mail", "com.tinyspeck.slackmacgap", "com.figma.Desktop"] {
            XCTAssertFalse(
                PasteSimulator.shouldUseControlKey(for: image, bundleID: app),
                "GUI app \(app) should receive ⌘V for images"
            )
        }
    }

    func testFilesNeverUseControl() {
        let files: ItemContent = .files([URL(fileURLWithPath: "/tmp/a")])
        XCTAssertFalse(PasteSimulator.shouldUseControlKey(for: files, bundleID: "com.apple.Terminal"))
    }

    func testEmptyBundleIDUsesCommand() {
        XCTAssertFalse(PasteSimulator.shouldUseControlKey(for: .image(filename: "x"), bundleID: ""))
    }

    func testKnownTerminalsIncludeClaudeCodeHosts() {
        XCTAssertTrue(PasteSimulator.terminalBundleIDs.contains("com.apple.Terminal"))
        XCTAssertTrue(PasteSimulator.terminalBundleIDs.contains("com.googlecode.iterm2"))
        XCTAssertTrue(PasteSimulator.terminalBundleIDs.contains("dev.warp.Warp-Stable"))
        XCTAssertTrue(PasteSimulator.terminalBundleIDs.contains("com.mitchellh.ghostty"))
    }
}
