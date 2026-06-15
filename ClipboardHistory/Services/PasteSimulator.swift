import Foundation
import AppKit
import Carbon.HIToolbox

enum PasteSimulator {
    static let terminalBundleIDs: Set<String> = [
        "com.apple.Terminal",
        "com.googlecode.iterm2",
        "dev.warp.Warp-Stable",
        "co.zeit.hyper",
        "org.alacritty",
        "net.kovidgoyal.kitty",
        "com.mitchellh.ghostty"
    ]

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
        sendV(modifier: shouldUseControlKey(for: content, bundleID: bundleID) ? .maskControl : .maskCommand)
    }

    static func shouldUseControlKey(for content: ItemContent, bundleID: String) -> Bool {
        guard case .image = content else { return false }
        return terminalBundleIDs.contains(bundleID)
    }

    private static func sendV(modifier: CGEventFlags) {
        let source = CGEventSource(stateID: .combinedSessionState)
        let v = CGKeyCode(kVK_ANSI_V)

        let down = CGEvent(keyboardEventSource: source, virtualKey: v, keyDown: true)
        down?.flags = modifier
        let up = CGEvent(keyboardEventSource: source, virtualKey: v, keyDown: false)
        up?.flags = modifier

        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }
}
