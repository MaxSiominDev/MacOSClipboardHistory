import XCTest
@testable import ClipboardHistory

@MainActor
final class HistoryStoreTests: XCTestCase {
    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("HistoryStoreTest-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    private func makeStore() -> HistoryStore {
        HistoryStore(baseURL: tempDir, autoPrune: false)
    }

    func testStartsEmpty() {
        XCTAssertEqual(makeStore().items.count, 0)
    }

    func testAddItemInsertsAtTop() {
        let store = makeStore()
        store.addItem(ClipboardItem(content: .text("a")))
        store.addItem(ClipboardItem(content: .text("b")))
        XCTAssertEqual(store.items.count, 2)
        XCTAssertEqual(store.items.first?.content, .text("b"))
        XCTAssertEqual(store.items.last?.content, .text("a"))
    }

    func testEvictsOldestWhenOverLimit() {
        let store = makeStore()
        for i in 0..<(HistoryStore.limit + 50) {
            store.addItem(ClipboardItem(content: .text("\(i)")))
        }
        XCTAssertEqual(store.items.count, HistoryStore.limit)
        // The 50 oldest items should be gone, so the bottom item is "50".
        XCTAssertEqual(store.items.last?.content, .text("50"))
        // And the top is the most recent insert.
        XCTAssertEqual(store.items.first?.content, .text("\(HistoryStore.limit + 49)"))
    }

    func testDeleteRemovesById() {
        let store = makeStore()
        let target = ClipboardItem(content: .text("target"))
        store.addItem(ClipboardItem(content: .text("a")))
        store.addItem(target)
        store.addItem(ClipboardItem(content: .text("c")))

        store.deleteItem(id: target.id)

        XCTAssertEqual(store.items.count, 2)
        XCTAssertFalse(store.items.contains(where: { $0.id == target.id }))
    }

    func testDeleteUnknownIdIsNoop() {
        let store = makeStore()
        store.addItem(ClipboardItem(content: .text("a")))
        store.deleteItem(id: UUID())
        XCTAssertEqual(store.items.count, 1)
    }

    func testClearAllEmptiesList() {
        let store = makeStore()
        for i in 0..<5 {
            store.addItem(ClipboardItem(content: .text("\(i)")))
        }
        store.clearAll()
        XCTAssertEqual(store.items.count, 0)
    }

    func testPromoteMovesItemToTop() {
        let store = makeStore()
        let bottom = ClipboardItem(content: .text("bottom"))
        store.addItem(bottom)
        store.addItem(ClipboardItem(content: .text("middle")))
        store.addItem(ClipboardItem(content: .text("top")))

        store.promote(id: bottom.id)

        XCTAssertEqual(store.items.first?.id, bottom.id)
        XCTAssertEqual(store.items.count, 3)
    }

    func testPromoteWhenAlreadyOnTopIsNoop() {
        let store = makeStore()
        let item = ClipboardItem(content: .text("solo"))
        store.addItem(item)
        store.promote(id: item.id)
        XCTAssertEqual(store.items.first?.id, item.id)
        XCTAssertEqual(store.items.count, 1)
    }

    func testPruneRemovesItemsOlderThanMaxAge() {
        let store = makeStore()
        let old = ClipboardItem(
            content: .text("old"),
            timestamp: Date().addingTimeInterval(-HistoryStore.maxAge - 60)
        )
        let recent = ClipboardItem(content: .text("recent"))

        let json = try! JSONEncoder().encode([old, recent])
        let path = tempDir.appendingPathComponent("history.json")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        try! json.write(to: path)

        let loaded = HistoryStore(baseURL: tempDir, autoPrune: false)
        XCTAssertEqual(loaded.items.count, 1)
        XCTAssertEqual(loaded.items.first?.content, .text("recent"))
    }

    func testPersistenceAcrossInstances() {
        let store = makeStore()
        store.addItem(ClipboardItem(content: .text("persist me")))

        let exp = expectation(description: "wait for debounced save")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            exp.fulfill()
        }
        wait(for: [exp], timeout: 3)

        let reloaded = HistoryStore(baseURL: tempDir, autoPrune: false)
        XCTAssertEqual(reloaded.items.count, 1)
        XCTAssertEqual(reloaded.items.first?.content, .text("persist me"))
    }
}
