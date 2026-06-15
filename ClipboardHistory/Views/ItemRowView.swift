import SwiftUI
import AppKit

struct ItemRowView: View {
    @EnvironmentObject var store: HistoryStore
    @Environment(\.pasteAction) private var pasteAction
    let item: ClipboardItem

    @State private var hovering = false

    var body: some View {
        Button {
            pasteAction(item)
        } label: {
            HStack(alignment: .top, spacing: 10) {
                contentView
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 4) {
                    Button {
                        store.deleteItem(id: item.id)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .imageScale(.medium)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .opacity(hovering ? 1 : 0)
                    .help("Delete")
                    Text(item.timestamp.formatted(.relative(presentation: .numeric)))
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .fixedSize()
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .background(hovering ? Color.gray.opacity(0.15) : Color.clear)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
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
