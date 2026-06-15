import SwiftUI
import AppKit
import ApplicationServices

extension Notification.Name {
    static let showStatusIconChanged = Notification.Name("showStatusIconChanged")
}

enum Prefs {
    static let showStatusIcon = "showStatusIcon"
}

@main
struct ClipboardHistoryApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = HistoryStore()
    private lazy var watcher = ClipboardWatcher(store: store)
    private let hotKey = HotKeyManager()

    private var statusItem: NSStatusItem!
    private var panel: PopupPanel!
    private var themeWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.register(defaults: [Prefs.showStatusIcon: true])
        NSApp.setActivationPolicy(.accessory)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Clipboard History")
            button.action = #selector(handleStatusItemClick)
            button.target = self
        }
        statusItem.isVisible = UserDefaults.standard.bool(forKey: Prefs.showStatusIcon)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applyStatusIconVisibility),
            name: .showStatusIconChanged,
            object: nil
        )

        let pasteAction: @MainActor (ClipboardItem) -> Void = { [weak self] item in
            self?.performPaste(item)
        }

        panel = PopupPanel(
            content: PopupView()
                .environmentObject(store)
                .environment(\.pasteAction, pasteAction)
        )

        watcher.start()

        hotKey.onHotKey = { [weak self] in
            self?.toggleFromHotKey()
        }
        hotKey.start()

        if !UserDefaults.standard.bool(forKey: ThemePrefs.hasSelectedTheme) {
            presentThemePicker()
        } else {
            showPanelOnLaunchIfUserInitiated()
        }
    }

    private func presentThemePicker() {
        let hosting = NSHostingController(rootView: ThemePickerView { [weak self] in
            self?.themeWindow?.close()
        })
        let window = NSWindow(contentViewController: hosting)
        window.title = "ClipboardHistory"
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.isReleasedWhenClosed = false
        window.center()
        window.level = .floating

        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { _ in
            UserDefaults.standard.set(true, forKey: ThemePrefs.hasSelectedTheme)
        }

        themeWindow = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func showPanelOnLaunchIfUserInitiated() {
        // 'lain' = keyAELaunchedAsLogInItem — set when launched via SMAppService
        // login items. Skip auto-show in that case so we don't pop up at boot.
        let loginItemKey = AEKeyword(0x6c61696e)
        let event = NSAppleEventManager.shared().currentAppleEvent
        let isLoginItem = event?.attributeDescriptor(forKeyword: loginItemKey)?.booleanValue ?? false
        if isLoginItem { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(300)) { [weak self] in
            self?.showPanelExternal()
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        if NSApp.activationPolicy() != .accessory {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showPanelExternal()
        return false
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls where url.scheme == "clipboardhistory" {
            switch url.host {
            case "theme":
                applyThemeURL(url)
            case "israel":
                applyLegacyIsraelURL(url)
            default:
                break
            }
            showPanelExternal()
            return
        }
    }

    private func applyThemeURL(_ url: URL) {
        let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let value = comps?.queryItems?.first(where: { $0.name == "value" })?.value ?? ""
        guard AppTheme(rawValue: value) != nil else { return }
        UserDefaults.standard.set(value, forKey: ThemePrefs.theme)
        UserDefaults.standard.set(true, forKey: ThemePrefs.hasSelectedTheme)
    }

    private func applyLegacyIsraelURL(_ url: URL) {
        let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let value = comps?.queryItems?.first(where: { $0.name == "value" })?.value
        let theme: AppTheme = (value == "on") ? .jewish : .default
        UserDefaults.standard.set(theme.rawValue, forKey: ThemePrefs.theme)
        UserDefaults.standard.set(true, forKey: ThemePrefs.hasSelectedTheme)
    }

    func applicationWillTerminate(_ notification: Notification) {
        watcher.stop()
        hotKey.stop()
    }

    private func showPanelExternal() {
        guard panel != nil else { return }
        if panel.isVisible { return }
        panel.targetApp = NSWorkspace.shared.frontmostApplication
        if let button = statusItem.button, statusItem.isVisible, button.window != nil {
            panel.show(below: button)
        } else {
            panel.showAtCursor()
        }
    }

    @objc private func handleStatusItemClick() {
        guard let button = statusItem.button else { return }
        if panel.isVisible {
            panel.hide()
        } else {
            panel.targetApp = NSWorkspace.shared.frontmostApplication
            panel.show(below: button)
        }
    }

    @objc private func applyStatusIconVisibility() {
        statusItem.isVisible = UserDefaults.standard.bool(forKey: Prefs.showStatusIcon)
    }

    private func toggleFromHotKey() {
        if panel.isVisible {
            panel.hide()
        } else {
            panel.targetApp = NSWorkspace.shared.frontmostApplication
            panel.showAtCursor()
        }
    }

    private func performPaste(_ item: ClipboardItem) {
        let content = item.content
        let target = panel.targetApp
        store.promote(id: item.id)
        PasteSimulator.setPasteboard(content, store: store)
        watcher.ignoreCurrentChange()
        panel.hide()
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(50)) {
            PasteSimulator.sendPaste(for: content, target: target)
        }
    }
}
