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

    // MARK: - Pin

    func testTogglePinMovesItemToTop() {
        let store = makeStore()
        store.addItem(ClipboardItem(content: .text("a")))
        let target = ClipboardItem(content: .text("target"))
        store.addItem(target)
        store.addItem(ClipboardItem(content: .text("c")))

        store.togglePin(id: target.id)

        XCTAssertEqual(store.items.first?.id, target.id)
        XCTAssertTrue(store.items.first?.isPinned ?? false)
        XCTAssertEqual(store.pinnedCount, 1)
    }

    func testUnpinMovesItemToTopOfUnpinnedSection() {
        let store = makeStore()
        let a = ClipboardItem(content: .text("a"))
        let b = ClipboardItem(content: .text("b"))
        store.addItem(a)
        store.addItem(b)
        store.togglePin(id: a.id)

        store.togglePin(id: a.id)

        XCTAssertEqual(store.pinnedCount, 0)
        XCTAssertEqual(store.items.first?.id, a.id)
        XCTAssertFalse(store.items.first?.isPinned ?? true)
    }

    func testPinLimitIsEnforced() {
        let store = makeStore()
        var pinnable: [ClipboardItem] = []
        for i in 0..<(HistoryStore.pinLimit + 5) {
            let item = ClipboardItem(content: .text("\(i)"))
            store.addItem(item)
            pinnable.append(item)
        }
        for item in pinnable {
            store.togglePin(id: item.id)
        }
        XCTAssertEqual(store.pinnedCount, HistoryStore.pinLimit)
    }

    func testPinnedItemsAreNotEvictedByLimit() {
        let store = makeStore()
        let pinned = ClipboardItem(content: .text("pinned"))
        store.addItem(pinned)
        store.togglePin(id: pinned.id)

        for i in 0..<(HistoryStore.limit + 10) {
            store.addItem(ClipboardItem(content: .text("u\(i)")))
        }

        XCTAssertTrue(store.items.contains { $0.id == pinned.id })
        XCTAssertEqual(store.items.filter { !$0.isPinned }.count, HistoryStore.limit)
        XCTAssertEqual(store.items.first?.isPinned, true)
    }

    func testPinnedItemsAreNotPrunedByTTL() {
        let oldPinned = ClipboardItem(
            content: .text("ancient"),
            timestamp: Date().addingTimeInterval(-HistoryStore.maxAge - 100),
            isPinned: true
        )
        let oldUnpinned = ClipboardItem(
            content: .text("old"),
            timestamp: Date().addingTimeInterval(-HistoryStore.maxAge - 100)
        )
        let recent = ClipboardItem(content: .text("recent"))

        let json = try! JSONEncoder().encode([oldPinned, oldUnpinned, recent])
        let path = tempDir.appendingPathComponent("history.json")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        try! json.write(to: path)

        let loaded = HistoryStore(baseURL: tempDir, autoPrune: false)

        XCTAssertEqual(loaded.items.count, 2)
        XCTAssertTrue(loaded.items.contains { $0.id == oldPinned.id })
        XCTAssertFalse(loaded.items.contains { $0.id == oldUnpinned.id })
    }

    func testAddItemInsertsAfterPinnedSection() {
        let store = makeStore()
        let pinned = ClipboardItem(content: .text("p"))
        store.addItem(pinned)
        store.togglePin(id: pinned.id)

        let fresh = ClipboardItem(content: .text("fresh"))
        store.addItem(fresh)

        XCTAssertEqual(store.items.first?.id, pinned.id)
        XCTAssertEqual(store.items[1].id, fresh.id)
    }

    func testPromoteUnpinnedDoesNotCrossPinnedSection() {
        let store = makeStore()
        let pinned = ClipboardItem(content: .text("p"))
        store.addItem(pinned)
        store.togglePin(id: pinned.id)

        store.addItem(ClipboardItem(content: .text("u1")))
        let bottom = ClipboardItem(content: .text("u-bottom"))
        store.addItem(bottom)
        store.promote(id: bottom.id)
        XCTAssertEqual(store.items.first?.id, pinned.id, "pinned still on top")

        let u1Id = store.items.last!.id
        store.promote(id: u1Id)
        XCTAssertEqual(store.items[1].id, u1Id)
    }

    func testPromotePinnedMovesWithinPinnedSection() {
        let store = makeStore()
        let p1 = ClipboardItem(content: .text("p1"), timestamp: Date().addingTimeInterval(-100))
        let p2 = ClipboardItem(content: .text("p2"), timestamp: Date())
        store.addItem(p1)
        store.addItem(p2)
        store.togglePin(id: p1.id)
        store.togglePin(id: p2.id)

        store.promote(id: p1.id)
        XCTAssertEqual(store.items.first?.id, p1.id)
        XCTAssertEqual(store.items[1].id, p2.id)
    }

    func testPinnedSectionSortedByTimestampDesc() {
        let store = makeStore()
        let oldest = ClipboardItem(content: .text("oldest"), timestamp: Date().addingTimeInterval(-300))
        let middle = ClipboardItem(content: .text("middle"), timestamp: Date().addingTimeInterval(-200))
        let newest = ClipboardItem(content: .text("newest"), timestamp: Date().addingTimeInterval(-100))
        store.addItem(oldest)
        store.addItem(middle)
        store.addItem(newest)

        store.togglePin(id: oldest.id)
        store.togglePin(id: newest.id)
        store.togglePin(id: middle.id)

        XCTAssertEqual(store.items[0].id, newest.id)
        XCTAssertEqual(store.items[1].id, middle.id)
        XCTAssertEqual(store.items[2].id, oldest.id)
    }

    func testRepinningAfterPromoteRestoresTimestampOrder() {
        let store = makeStore()
        let a = ClipboardItem(content: .text("a"), timestamp: Date().addingTimeInterval(-200))
        let b = ClipboardItem(content: .text("b"), timestamp: Date().addingTimeInterval(-100))
        store.addItem(a)
        store.addItem(b)
        store.togglePin(id: a.id)
        store.togglePin(id: b.id)

        store.promote(id: a.id)
        XCTAssertEqual(store.items[0].id, a.id)

        store.togglePin(id: a.id)
        store.togglePin(id: a.id)
        XCTAssertEqual(store.items[0].id, b.id)
        XCTAssertEqual(store.items[1].id, a.id)
    }
}
