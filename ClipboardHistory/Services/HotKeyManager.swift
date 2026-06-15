import Foundation
import AppKit
import ApplicationServices
import Carbon.HIToolbox

final class HotKeyManager {
    var onHotKey: (@MainActor () -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var permissionPollTask: Task<Void, Never>?

    func start() {
        guard eventTap == nil else { return }
        if installEventTap() { return }

        requestAccessibilityPermission()
        startPermissionPolling()
    }

    func stop() {
        permissionPollTask?.cancel()
        permissionPollTask = nil
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }

    @discardableResult
    private func installEventTap() -> Bool {
        guard AXIsProcessTrusted() else { return false }

        let mask: CGEventMask = 1 << CGEventType.keyDown.rawValue
        let refcon = Unmanaged.passUnretained(self).toOpaque()

        let callback: CGEventTapCallBack = { _, type, event, refcon in
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let refcon {
                    let mgr = Unmanaged<HotKeyManager>.fromOpaque(refcon).takeUnretainedValue()
                    if let tap = mgr.eventTap {
                        CGEvent.tapEnable(tap: tap, enable: true)
                    }
                }
                return Unmanaged.passUnretained(event)
            }

            guard type == .keyDown else { return Unmanaged.passUnretained(event) }

            let keycode = event.getIntegerValueField(.keyboardEventKeycode)
            let isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
            let flags = event.flags
            let isCmd = flags.contains(.maskCommand)
            let isShift = flags.contains(.maskShift)
            let isV = keycode == Int64(kVK_ANSI_V)

            if isCmd && isShift && isV && !isRepeat {
                if let refcon {
                    let mgr = Unmanaged<HotKeyManager>.fromOpaque(refcon).takeUnretainedValue()
                    Task { @MainActor in
                        mgr.onHotKey?()
                    }
                }
                return nil
            }

            return Unmanaged.passUnretained(event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: refcon
        ) else {
            return false
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        eventTap = tap
        runLoopSource = source
        return true
    }

    private func requestAccessibilityPermission() {
        NSApp.activate(ignoringOtherApps: true)
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options: NSDictionary = [key: true]
        _ = AXIsProcessTrustedWithOptions(options)
    }

    private func startPermissionPolling() {
        permissionPollTask?.cancel()
        permissionPollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))
                guard let self else { return }
                if self.installEventTap() {
                    return
                }
            }
        }
    }
}
