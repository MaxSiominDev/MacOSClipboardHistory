import XCTest
@testable import ClipboardHistory

final class ClipboardItemTests: XCTestCase {
    func testInitDefaultsIdAndTimestamp() {
        let before = Date()
        let item = ClipboardItem(content: .text("a"))
        let after = Date()
        XCTAssertGreaterThanOrEqual(item.timestamp, before)
        XCTAssertLessThanOrEqual(item.timestamp, after)
        XCTAssertFalse(item.id.uuidString.isEmpty)
    }

    func testCodableRoundTrip() throws {
        let id = UUID()
        let when = Date(timeIntervalSince1970: 800_000_000)
        let original = ClipboardItem(id: id, content: .text("payload"), timestamp: when)

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ClipboardItem.self, from: data)

        XCTAssertEqual(decoded.id, id)
        XCTAssertEqual(decoded.content, .text("payload"))
        XCTAssertEqual(decoded.timestamp.timeIntervalSince1970, when.timeIntervalSince1970, accuracy: 0.001)
    }

    func testArrayRoundTripPreservesOrder() throws {
        let items = (0..<5).map { i in
            ClipboardItem(content: .text("item \(i)"))
        }
        let data = try JSONEncoder().encode(items)
        let decoded = try JSONDecoder().decode([ClipboardItem].self, from: data)
        XCTAssertEqual(decoded.map(\.id), items.map(\.id))
    }
}
