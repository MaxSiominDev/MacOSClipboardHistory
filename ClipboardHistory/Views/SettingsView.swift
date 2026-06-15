import SwiftUI
import AppKit
import ApplicationServices
import Combine

struct SettingsView: View {
    @EnvironmentObject var store: HistoryStore
    let close: () -> Void

    @State private var launchAtLogin: Bool = LaunchAtLoginManager.isEnabled
    @AppStorage(Prefs.showStatusIcon) private var showStatusIcon: Bool = true
    @AppStorage(ThemePrefs.theme) private var theme: AppTheme = .default
    @State private var showClearConfirm = false
    @State private var axTrusted: Bool = AXIsProcessTrusted()

    private let axTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            Divider()

            Toggle("Launch at login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, newValue in
                    if !LaunchAtLoginManager.setEnabled(newValue) {
                        launchAtLogin = LaunchAtLoginManager.isEnabled
                    }
                }

            Toggle("Show menu bar icon", isOn: $showStatusIcon)
                .onChange(of: showStatusIcon) { _, _ in
                    NotificationCenter.default.post(name: .showStatusIconChanged, object: nil)
                }

            Picker("Theme", selection: $theme) {
                ForEach(AppTheme.allCases) { option in
                    Text(option.displayName).tag(option)
                }
            }
            .pickerStyle(.segmented)

            Divider()

            accessibilitySection

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                infoRow("Items:", "\(store.items.count) / \(HistoryStore.limit)")
                infoRow("Disk usage:", sizeString)
            }
            .font(.callout)

            Button("Clear all history") {
                showClearConfirm = true
            }
            .disabled(store.items.isEmpty)

            Spacer(minLength: 0)

            HStack {
                Spacer()
                Button("Quit ClipboardHistory") {
                    NSApp.terminate(nil)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onReceive(axTimer) { _ in
            axTrusted = AXIsProcessTrusted()
        }
        .alert("Clear all history?", isPresented: $showClearConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                store.clearAll()
            }
        } message: {
            Text("This will permanently delete all clipboard items.")
        }
    }

    private var header: some View {
        HStack {
            Button {
                close()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                    Text("Back")
                }
            }
            .buttonStyle(.plain)
            Spacer()
            Text("Settings")
                .font(.headline)
            Spacer()
            Color.clear.frame(width: 50, height: 1)
        }
    }

    private var accessibilitySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Circle()
                    .fill(axTrusted ? Color.green : Color.red)
                    .frame(width: 9, height: 9)
                Text(axTrusted ? "Hotkey & paste enabled" : "Accessibility permission needed")
                    .font(.callout)
            }
            if !axTrusted {
                Text("⌘⇧V and pasting items require Accessibility access. Rebuilding the app can revoke it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Open Accessibility Settings") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        }
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value).foregroundStyle(.secondary)
        }
    }

    private var sizeString: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: store.diskSize())
    }
}
