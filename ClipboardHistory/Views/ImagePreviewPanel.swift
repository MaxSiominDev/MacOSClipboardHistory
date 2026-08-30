import AppKit
import SwiftUI

/// Full-screen dimmed overlay showing one clipboard image while its row is held down.
final class ImagePreviewPanel: NSPanel {
    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = NSWindow.Level(rawValue: NSWindow.Level.popUpMenu.rawValue + 1)
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        animationBehavior = .none
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        ignoresMouseEvents = true
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func show(image: NSImage, on screen: NSScreen) {
        let size = ImagePreviewLayout.fittedSize(image: image.size, screen: screen.frame.size)
        guard size.width > 0, size.height > 0 else { return }
        let hosting = NSHostingView(rootView: ImagePreviewView(image: image, size: size))
        hosting.frame = NSRect(origin: .zero, size: screen.frame.size)
        contentView = hosting
        setFrame(screen.frame, display: false)
        orderFrontRegardless()
    }

    func hide() {
        orderOut(nil)
        contentView = nil
    }
}
