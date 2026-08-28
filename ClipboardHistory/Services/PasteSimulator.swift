import Foundation
import AppKit
import Carbon.HIToolbox

enum PasteSimulator {
    enum PasteMethod {
        case commandV
        case controlV
    }

    static let terminalBundleIDs: Set<String> = [
        "com.apple.Terminal",
        "com.googlecode.iterm2",
        "dev.warp.Warp-Stable",
        "co.zeit.hyper",
        "org.alacritty",
        "net.kovidgoyal.kitty",
        "com.mitchellh.ghostty"
    ]

    private static let controlVCharacter: UniChar = 0x16

    static func setPasteboard(_ content: ItemContent, store: HistoryStore) {
        let pb = NSPasteboard.general
        pb.clearContents()

        switch content {
        case .text(let s):
            pb.setString(s, forType: .string)
        case .image(let filename):
            if let image = NSImage(contentsOf: store.imageURL(for: filename)) {
                pb.writeObjects([image])
            }
        case .files(let urls):
            pb.writeObjects(urls.map { $0 as NSURL })
        }
    }

    static func sendPaste(for content: ItemContent, target: NSRunningApplication?) {
        let bundleID = target?.bundleIdentifier
            ?? NSWorkspace.shared.frontmostApplication?.bundleIdentifier
            ?? ""
        for event in keystrokeEvents(for: pasteMethod(for: content, bundleID: bundleID)) {
            event.post(tap: .cghidEventTap)
        }
    }

    static func pasteMethod(for content: ItemContent, bundleID: String) -> PasteMethod {
        guard case .image = content, terminalBundleIDs.contains(bundleID) else { return .commandV }
        return .controlV
    }

    static func keystrokeEvents(for method: PasteMethod) -> [CGEvent] {
        let source = CGEventSource(stateID: .combinedSessionState)
        let down = keystroke(keyDown: true, method: method, source: source)
        let up = keystroke(keyDown: false, method: method, source: source)
        return [down, up].compactMap { $0 }
    }

    private static func keystroke(keyDown: Bool, method: PasteMethod, source: CGEventSource?) -> CGEvent? {
        guard let event = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: keyDown) else {
            return nil
        }

        switch method {
        case .commandV:
            event.flags = .maskCommand
        case .controlV:
            // Terminals on the kitty keyboard protocol (Claude Code turns it on in Warp) report keys by
            // the active layout's codepoint, so a synthesized Ctrl+V never arrives as ^V outside Latin layouts.
            event.flags = []
            var character = controlVCharacter
            event.keyboardSetUnicodeString(stringLength: 1, unicodeString: &character)
        }
        return event
    }
}
