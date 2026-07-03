import SwiftUI
import AppKit
import ApplicationServices
import Combine

struct PopupView: View {
    @EnvironmentObject var store: HistoryStore
    @AppStorage(ThemePrefs.theme) private var theme: AppTheme = .default
    @Environment(\.activatePanelKeyboard) private var activatePanelKeyboard
    @State private var showSettings = false
    @State private var axTrusted: Bool = AXIsProcessTrusted()
    @State private var searchVisible = false
    @State private var searchQuery = ""
    @State private var scrolledFromTop = false
    @FocusState private var searchFocused: Bool

    private let axTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var filteredItems: [ClipboardItem] {
        guard !searchQuery.isEmpty else { return store.items }
        let q = searchQuery.lowercased()
        return store.items.filter { item in
            if case .text(let s) = item.content {
                return s.lowercased().contains(q)
            }
            return false
        }
    }

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
            closeSearch()
        }
        .onReceive(NotificationCenter.default.publisher(for: .popupOpenSearch)) { _ in
            openSearch()
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

    @ViewBuilder
    private var header: some View {
        if searchVisible {
            searchHeader
        } else {
            defaultHeader
        }
    }

    private var defaultHeader: some View {
        HStack(spacing: 8) {
            Text("Clipboard History")
                .font(.headline)
            Spacer()
            Button {
                openSearch()
            } label: {
                Image(systemName: "magnifyingglass")
                    .imageScale(.medium)
            }
            .buttonStyle(.plain)
            .help("Search (⌘F)")
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

    private var searchHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search", text: $searchQuery)
                .textFieldStyle(.plain)
                .focused($searchFocused)
                .onExitCommand { closeSearch() }
            Button {
                closeSearch()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Close (Esc)")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var content: some View {
        let items = filteredItems
        if items.isEmpty {
            VStack {
                Spacer()
                Text(emptyText)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                Spacer()
            }
            .frame(maxWidth: .infinity)
        } else {
            ScrollViewReader { proxy in
                ZStack(alignment: .topTrailing) {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(items) { item in
                                ItemRowView(item: item)
                                    .environmentObject(store)
                                    .id(item.id)
                                Divider()
                            }
                        }
                    }
                    .onScrollGeometryChange(for: Bool.self) { geom in
                        geom.contentOffset.y > 100
                    } action: { _, scrolled in
                        scrolledFromTop = scrolled
                    }

                    if scrolledFromTop, let first = items.first {
                        Button {
                            withAnimation(.easeOut(duration: 0.2)) {
                                proxy.scrollTo(first.id, anchor: .top)
                            }
                        } label: {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.primary)
                                .padding(8)
                                .background(.regularMaterial, in: Circle())
                                .overlay(Circle().strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5))
                        }
                        .buttonStyle(.plain)
                        .padding(10)
                        .transition(.opacity)
                        .help("Scroll to top")
                    }
                }
            }
        }
    }

    private var emptyText: String {
        if !searchQuery.isEmpty {
            return "No matches for \"\(searchQuery)\"."
        }
        return "Empty. Press ⌘⇧V after copying something."
    }

    private func openSearch() {
        showSettings = false
        activatePanelKeyboard()
        searchVisible = true
        DispatchQueue.main.async {
            searchFocused = true
        }
    }

    private func closeSearch() {
        searchVisible = false
        searchQuery = ""
        searchFocused = false
    }
}
