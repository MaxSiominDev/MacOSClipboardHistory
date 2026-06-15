import XCTest
@testable import ClipboardHistory

final class AppThemeTests: XCTestCase {
    func testRawValuesAreStable() {
        XCTAssertEqual(AppTheme.default.rawValue, "default")
        XCTAssertEqual(AppTheme.jewish.rawValue, "jewish")
    }

    func testInitFromRawValue() {
        XCTAssertEqual(AppTheme(rawValue: "default"), .default)
        XCTAssertEqual(AppTheme(rawValue: "jewish"), .jewish)
        XCTAssertNil(AppTheme(rawValue: "unknown"))
    }

    func testAllCasesIncludeBoth() {
        XCTAssertEqual(Set(AppTheme.allCases), Set([.default, .jewish]))
    }

    func testDisplayName() {
        XCTAssertEqual(AppTheme.default.displayName, "Default")
        XCTAssertEqual(AppTheme.jewish.displayName, "Jewish")
    }
}
