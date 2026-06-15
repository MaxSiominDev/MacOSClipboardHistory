import Foundation
import AppKit
import Combine

final class HistoryStore: ObservableObject {
    static let limit = 300
    static let maxAge: TimeInterval = 2 * 24 * 3600  // 2 days

    @Published private(set) var items: [ClipboardItem] = []

    let imagesURL: URL
    private let baseURL: URL
    private let jsonURL: URL
    private var saveTask: Task<Void, Never>?
    private var pruneTimer: Timer?

    convenience init() {
        self.init(baseURL: nil, autoPrune: true)
    }

    init(baseURL overrideBase: URL?, autoPrune: Bool) {
        let resolvedBase: URL
        if let overrideBase {
            resolvedBase = overrideBase
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            resolvedBase = appSupport.appendingPathComponent("ClipboardHistory", isDirectory: true)
        }
        self.baseURL = resolvedBase
        self.jsonURL = resolvedBase.appendingPathComponent("history.json")
        self.imagesURL = resolvedBase.appendingPathComponent("images", isDirectory: true)
        try? FileManager.default.createDirectory(at: self.imagesURL, withIntermediateDirectories: true)
        load()
        if autoPrune {
            startPruneTimer()
        }
    }

    func imageURL(for filename: String) -> URL {
        imagesURL.appendingPathComponent(filename)
    }

    func addItem(_ item: ClipboardItem) {
        pruneExpired(scheduleSaveIfChanged: false)
        items.insert(item, at: 0)
        while items.count > Self.limit {
            let removed = items.removeLast()
            deleteFile(for: removed)
        }
        scheduleSave()
    }

    func promote(id: UUID) {
        guard let idx = items.firstIndex(where: { $0.id == id }), idx > 0 else { return }
        let item = items.remove(at: idx)
        items.insert(item, at: 0)
        scheduleSave()
    }

    func deleteItem(id: UUID) {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        let removed = items.remove(at: idx)
        deleteFile(for: removed)
        scheduleSave()
    }

    func clearAll() {
        for item in items {
            deleteFile(for: item)
        }
        items.removeAll()
        scheduleSave()
    }

    func diskSize() -> Int64 {
        var total: Int64 = 0
        if let attrs = try? FileManager.default.attributesOfItem(atPath: jsonURL.path),
           let size = attrs[.size] as? NSNumber {
            total += size.int64Value
        }
        if let contents = try? FileManager.default.contentsOfDirectory(at: imagesURL, includingPropertiesForKeys: [.fileSizeKey]) {
            for url in contents {
                if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    total += Int64(size)
                }
            }
        }
        return total
    }

    func pruneExpired(scheduleSaveIfChanged: Bool = true) {
        let cutoff = Date().addingTimeInterval(-Self.maxAge)
        var changed = false
        items.removeAll { item in
            if item.timestamp < cutoff {
                deleteFile(for: item)
                changed = true
                return true
            }
            return false
        }
        if changed && scheduleSaveIfChanged {
            scheduleSave()
        }
    }

    private func startPruneTimer() {
        let timer = Timer(timeInterval: 600, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.pruneExpired()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        pruneTimer = timer
    }

    private func deleteFile(for item: ClipboardItem) {
        if case .image(let filename) = item.content {
            try? FileManager.default.removeItem(at: imageURL(for: filename))
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: jsonURL),
              let decoded = try? JSONDecoder().decode([ClipboardItem].self, from: data) else { return }
        items = decoded
        pruneExpired(scheduleSaveIfChanged: false)
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled, let self else { return }
            self.performSave()
        }
    }

    private func performSave() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        try? data.write(to: jsonURL, options: .atomic)
    }
}
