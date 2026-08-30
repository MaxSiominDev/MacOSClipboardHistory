import SwiftUI
import AppKit

struct ItemRowView: View {
    @EnvironmentObject var store: HistoryStore
    @Environment(\.pasteAction) private var pasteAction
    @Environment(\.showImagePreview) private var showImagePreview
    @Environment(\.hideImagePreview) private var hideImagePreview
    let item: ClipboardItem

    @State private var hovering = false
    @State private var holdTask: Task<Void, Never>?
    @State private var holdCompleted = false
    @State private var previewOpen = false

    var body: some View {
        Button {
            guard !holdCompleted else { return }
            pasteAction(item)
        } label: {
            HStack(alignment: .top, spacing: 10) {
                if item.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.tint)
                        .rotationEffect(.degrees(45))
                        .padding(.top, 2)
                }
                contentView
                    .contentShape(Rectangle())
                    .simultaneousGesture(holdGesture, isEnabled: isImage)
                Spacer(minLength: 8)
                trailingControls
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .background(hovering ? Color.gray.opacity(0.15) : Color.clear)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .onDisappear { endHold() }
    }

    private var isImage: Bool {
        if case .image = item.content { return true }
        return false
    }

    private var holdGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in beginHold() }
            .onEnded { _ in endHold() }
    }

    private func beginHold() {
        guard holdTask == nil else { return }
        // Reset only here: the click ending this hold can arrive after endHold(), and must not paste.
        holdCompleted = false
        holdTask = Task {
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            holdCompleted = true
            openPreview()
        }
    }

    private func endHold() {
        holdTask?.cancel()
        holdTask = nil
        if previewOpen {
            previewOpen = false
            hideImagePreview()
        }
    }

    private func openPreview() {
        guard case .image(let filename) = item.content,
              let image = NSImage(contentsOf: store.imageURL(for: filename)) else { return }
        previewOpen = true
        showImagePreview(image)
    }

    private var trailingControls: some View {
        VStack(alignment: .trailing, spacing: 4) {
            HStack(spacing: 6) {
                Button {
                    store.togglePin(id: item.id)
                } label: {
                    Image(systemName: item.isPinned ? "pin.slash" : "pin")
                        .imageScale(.small)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .disabled(!item.isPinned && store.pinnedCount >= HistoryStore.pinLimit)
                .help(item.isPinned ? "Unpin" : (store.pinnedCount >= HistoryStore.pinLimit ? "Pin limit reached (\(HistoryStore.pinLimit))" : "Pin"))

                Button {
                    store.promote(id: item.id)
                } label: {
                    Image(systemName: "arrow.up")
                        .imageScale(.small)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Move to top")

                Button {
                    store.deleteItem(id: item.id)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .imageScale(.medium)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Delete")
            }
            .opacity(hovering ? 1 : 0)

            Text(item.timestamp.formatted(.relative(presentation: .numeric)))
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .fixedSize()
        }
    }

    @ViewBuilder
    private var contentView: some View {
        switch item.content {
        case .text(let s):
            Text(s)
                .font(.system(size: 13))
                .lineLimit(3)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)

        case .image(let filename):
            HStack(spacing: 10) {
                imageThumb(filename: filename)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Image")
                        .font(.system(size: 13, weight: .medium))
                    if let dims = imageDimensions(filename: filename) {
                        Text(dims)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

        case .files(let urls):
            HStack(spacing: 10) {
                Image(systemName: urls.count > 1 ? "doc.on.doc" : "doc")
                    .font(.system(size: 22))
                    .foregroundStyle(.secondary)
                    .frame(width: 30)
                Text(filesLabel(urls))
                    .font(.system(size: 13))
                    .lineLimit(2)
                    .truncationMode(.middle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func imageThumb(filename: String) -> some View {
        Group {
            if let img = NSImage(contentsOf: store.imageURL(for: filename)) {
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "photo")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 60, height: 60)
        .background(Color.gray.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private func imageDimensions(filename: String) -> String? {
        let url = store.imageURL(for: filename)
        guard let img = NSImage(contentsOf: url) else { return nil }
        if let rep = img.representations.first as? NSBitmapImageRep {
            return "\(rep.pixelsWide)×\(rep.pixelsHigh)"
        }
        return "\(Int(img.size.width))×\(Int(img.size.height))"
    }

    private func filesLabel(_ urls: [URL]) -> String {
        if urls.count > 3 {
            return "\(urls.count) files"
        }
        return urls.map { $0.lastPathComponent }.joined(separator: ", ")
    }
}
