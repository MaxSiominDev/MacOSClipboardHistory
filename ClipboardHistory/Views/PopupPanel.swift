import AppKit
import ApplicationServices
import SwiftUI

extension Notification.Name {
    static let popupWillShow = Notification.Name("popupWillShow")
}

final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    required init(rootView: Content) {
        super.init(rootView: rootView)
    }

    @MainActor required dynamic init?(coder: NSCoder) {
        super.init(coder: coder)
    }
}

final class PopupPanel: NSPanel {
    static let size = NSSize(width: 360, height: 500)

    private(set) var lastHideTime: TimeInterval = 0
    var targetApp: NSRunningApplication?
    private var globalClickMonitor: Any?

    init<Content: View>(content: Content) {
        super.init(
            contentRect: NSRect(origin: .zero, size: Self.size),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .popUpMenu
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        animationBehavior = .utilityWindow
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        worksWhenModal = true

        let hosting = FirstMouseHostingView(rootView: content)
        hosting.frame = NSRect(origin: .zero, size: Self.size)
        contentView = hosting
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func cancelOperation(_ sender: Any?) {
        hide()
    }

    var recentlyHidden: Bool {
        ProcessInfo.processInfo.systemUptime - lastHideTime < 0.15
    }

    func toggle(below button: NSStatusBarButton) {
        if isVisible {
            hide()
        } else if !recentlyHidden {
            show(below: button)
        }
    }

    func show(below button: NSStatusBarButton) {
        guard let buttonWindow = button.window else { return }
        let buttonRect = button.convert(button.bounds, to: nil)
        let screenRect = buttonWindow.convertToScreen(buttonRect)
        let anchor = NSPoint(x: screenRect.midX, y: screenRect.minY - 4)
        placeBelow(anchorTop: anchor)
        present()
    }

    func showAtCursor() {
        if let caret = focusedTextCaretBounds(), caret.height > 0 {
            placeAvoiding(caret)
        } else {
            let mouse = NSEvent.mouseLocation
            placeBelow(anchorTop: NSPoint(x: mouse.x, y: mouse.y - 4))
        }
        present()
    }

    func hide() {
        lastHideTime = ProcessInfo.processInfo.systemUptime
        removeOutsideClickMonitor()
        orderOut(nil)
    }

    private func present() {
        orderFrontRegardless()
        invalidateShadow()
        installOutsideClickMonitor()
        NotificationCenter.default.post(name: .popupWillShow, object: nil)
    }

    private func placeBelow(anchorTop: NSPoint) {
        let visible = visibleFrame(near: anchorTop)
        let margin: CGFloat = 8
        var x = anchorTop.x - Self.size.width / 2
        var y = anchorTop.y - Self.size.height
        x = max(visible.minX + margin, min(x, visible.maxX - Self.size.width - margin))
        y = max(visible.minY + margin, min(y, visible.maxY - Self.size.height - margin))
        setFrameOrigin(NSPoint(x: x, y: y))
    }

    /// Position the panel next to `caret` without overlapping it.
    /// Tries below → above → right → left, clamping to the screen.
    private func placeAvoiding(_ caret: NSRect) {
        let visible = visibleFrame(near: NSPoint(x: caret.midX, y: caret.midY))
        let margin: CGFloat = 8
        let gap: CGFloat = 6
        let w = Self.size.width
        let h = Self.size.height

        // Below the caret
        if caret.minY - gap - h >= visible.minY + margin {
            var x = caret.midX - w / 2
            x = max(visible.minX + margin, min(x, visible.maxX - w - margin))
            setFrameOrigin(NSPoint(x: x, y: caret.minY - gap - h))
            return
        }

        // Above the caret
        if caret.maxY + gap + h <= visible.maxY - margin {
            var x = caret.midX - w / 2
            x = max(visible.minX + margin, min(x, visible.maxX - w - margin))
            setFrameOrigin(NSPoint(x: x, y: caret.maxY + gap))
            return
        }

        // To the right of caret
        if caret.maxX + gap + w <= visible.maxX - margin {
            var y = caret.midY - h / 2
            y = max(visible.minY + margin, min(y, visible.maxY - h - margin))
            setFrameOrigin(NSPoint(x: caret.maxX + gap, y: y))
            return
        }

        // To the left of caret
        if caret.minX - gap - w >= visible.minX + margin {
            var y = caret.midY - h / 2
            y = max(visible.minY + margin, min(y, visible.maxY - h - margin))
            setFrameOrigin(NSPoint(x: caret.minX - gap - w, y: y))
            return
        }

        // No room — clamp to visible area, centered
        let x = max(visible.minX + margin, min(caret.midX - w / 2, visible.maxX - w - margin))
        let y = max(visible.minY + margin, min(caret.midY - h / 2, visible.maxY - h - margin))
        setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func visibleFrame(near point: NSPoint) -> NSRect {
        let screen = NSScreen.screens.first { NSMouseInRect(point, $0.frame, false) }
            ?? NSScreen.main
            ?? NSScreen.screens.first
        return screen?.visibleFrame ?? .zero
    }

    private func installOutsideClickMonitor() {
        removeOutsideClickMonitor()
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.hide()
        }
    }

    private func removeOutsideClickMonitor() {
        if let monitor = globalClickMonitor {
            NSEvent.removeMonitor(monitor)
            globalClickMonitor = nil
        }
    }

    private func focusedTextCaretBounds() -> NSRect? {
        let systemElement = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(systemElement, 0.1)

        var appRef: AnyObject?
        guard AXUIElementCopyAttributeValue(systemElement, kAXFocusedApplicationAttribute as CFString, &appRef) == .success,
              let appRef else { return nil }
        let app = appRef as! AXUIElement

        var elementRef: AnyObject?
        guard AXUIElementCopyAttributeValue(app, kAXFocusedUIElementAttribute as CFString, &elementRef) == .success,
              let elementRef else { return nil }
        let element = elementRef as! AXUIElement

        var rangeRef: AnyObject?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &rangeRef) == .success,
              let rangeRef else { return nil }

        var boundsRef: AnyObject?
        guard AXUIElementCopyParameterizedAttributeValue(element, kAXBoundsForRangeParameterizedAttribute as CFString, rangeRef, &boundsRef) == .success,
              let boundsRef else { return nil }

        var rect = CGRect.zero
        guard AXValueGetValue(boundsRef as! AXValue, .cgRect, &rect) else { return nil }

        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        let nsY = primaryHeight - rect.maxY
        return NSRect(x: rect.minX, y: nsY, width: rect.width, height: rect.height)
    }
}

extension EnvironmentValues {
    @Entry var pasteAction: @MainActor (ClipboardItem) -> Void = { _ in }
}
