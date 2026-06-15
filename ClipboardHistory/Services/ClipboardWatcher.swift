import Foundation
import AppKit

final class ClipboardWatcher {
    private let store: HistoryStore
    private let pasteboard = NSPasteboard.general
    private var lastChangeCount: Int
    private var timer: Timer?

    init(store: HistoryStore) {
        self.store = store
        self.lastChangeCount = pasteboard.changeCount
    }

    func start() {
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.check()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func ignoreCurrentChange() {
        lastChangeCount = pasteboard.changeCount
    }

    private func check() {
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount

        if let urls = readFileURLs() {
            if case .files(let existing) = store.items.first?.content, existing == urls { return }
            store.addItem(ClipboardItem(content: .files(urls)))
            return
        }

        if let imageData = readImageData() {
            if case .image(let filename) = store.items.first?.content,
               let existing = try? Data(contentsOf: store.imageURL(for: filename)),
               existing == imageData {
                return
            }
            let filename = "\(UUID().uuidString).png"
            do {
                try imageData.write(to: store.imageURL(for: filename))
                store.addItem(ClipboardItem(content: .image(filename: filename)))
            } catch {}
            return
        }

        if let s = pasteboard.string(forType: .string), !s.isEmpty {
            if case .text(let existing) = store.items.first?.content, existing == s { return }
            store.addItem(ClipboardItem(content: .text(s)))
        }
    }

    private func readFileURLs() -> [URL]? {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        guard let objects = pasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL],
              !objects.isEmpty else { return nil }
        return objects
    }

    private func readImageData() -> Data? {
        if let png = pasteboard.data(forType: .png) {
            return png
        }
        if let tiff = pasteboard.data(forType: .tiff),
           let rep = NSBitmapImageRep(data: tiff),
           let png = rep.representation(using: .png, properties: [:]) {
            return png
        }
        return nil
    }
}
