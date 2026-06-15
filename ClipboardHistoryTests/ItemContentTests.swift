import XCTest
@testable import ClipboardHistory

final class ItemContentTests: XCTestCase {
    func testTextRoundTrip() throws {
        let original: ItemContent = .text("hello world\n линия 2")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ItemContent.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testImageRoundTrip() throws {
        let original: ItemContent = .image(filename: "abc-123.png")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ItemContent.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testFilesRoundTrip() throws {
        let urls = [
            URL(fileURLWithPath: "/tmp/a.txt"),
            URL(fileURLWithPath: "/tmp/b с пробелом.pdf"),
        ]
        let original: ItemContent = .files(urls)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ItemContent.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testEncodedShapeHasTypeAndValue() throws {
        let data = try JSONEncoder().encode(ItemContent.text("hi"))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(json["type"] as? String, "text")
        XCTAssertEqual(json["value"] as? String, "hi")
    }

    func testDecodeUnknownTypeThrows() {
        let payload = #"{"type":"unknown","value":"x"}"#.data(using: .utf8)!
        XCTAssertThrowsError(try JSONDecoder().decode(ItemContent.self, from: payload))
    }

    func testTextNotEqualToImageWithSameValue() {
        XCTAssertNotEqual(ItemContent.text("a"), ItemContent.image(filename: "a"))
    }
}
