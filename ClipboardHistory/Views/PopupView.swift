import SwiftUI
import AppKit
import ApplicationServices
import Combine

struct PopupView: View {
    @EnvironmentObject var store: HistoryStore
    @AppStorage(ThemePrefs.theme) private var theme: AppTheme = .default
    @State private var showSettings = false
    @State private var axTrusted: Bool = AXIsProcessTrusted()

    private let axTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            if showSettings {
                SettingsView(close: { showSettings = false })
                    .environmentObject(store)
            } else {
                list
            }
        }
        .frame(width: 360, height: 500)
        .background(backgroundLayer)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
        )
        .onReceive(NotificationCenter.default.publisher(for: .popupWillShow)) { _ in
            showSettings = false
            axTrusted = AXIsProcessTrusted()
        }
        .onReceive(axTimer) { _ in
            axTrusted = AXIsProcessTrusted()
        }
    }

    @ViewBuilder
    private var backgroundLayer: some View {
        switch theme {
        case .default:
            Rectangle().fill(.regularMaterial)
        case .jewish:
            ZStack {
                Color.white
                Text("\u{2721}")
                    .font(.system(size: 180))
                    .foregroundStyle(Color(red: 0.0, green: 0.36, blue: 0.90).opacity(0.18))
            }
        }
    }

    private var list: some View {
        VStack(spacing: 0) {
            header
            if !axTrusted {
                axBanner
            }
            Divider()
            content
        }
    }

    private var axBanner: some View {
        Button {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Accessibility access required")
                        .font(.system(size: 12, weight: .medium))
                    Text("⌘⇧V and paste won't work until granted. Click to open Settings.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.orange.opacity(0.12))
        }
        .buttonStyle(.plain)
    }

    private var header: some View {
        HStack {
            Text("Clipboard History")
                .font(.headline)
            Spacer()
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .imageScale(.medium)
            }
            .buttonStyle(.plain)
            .help("Settings")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var content: some View {
        if store.items.isEmpty {
            VStack {
                Spacer()
                Text("Empty. Press ⌘⇧V after copying something.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                Spacer()
            }
            .frame(maxWidth: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(store.items) { item in
                        ItemRowView(item: item)
                            .environmentObject(store)
                        Divider()
                    }
                }
            }
        }
    }
}
