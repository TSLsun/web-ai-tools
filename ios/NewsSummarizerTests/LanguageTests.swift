import XCTest
@testable import NewsSummarizer

final class LanguageTests: XCTestCase {
    func testAllCasesPresent() {
        XCTAssertEqual(Language.allCases.count, 4)
    }

    func testRawValues() {
        XCTAssertEqual(Language.zhTW.rawValue, "zh-TW")
        XCTAssertEqual(Language.enUS.rawValue, "en-US")
        XCTAssertEqual(Language.ja.rawValue, "ja")
        XCTAssertEqual(Language.de.rawValue, "de")
    }

    func testDefaultIsZhTW() {
        XCTAssertEqual(Language.default, .zhTW)
    }

    func testDisplayNames() {
        XCTAssertEqual(Language.zhTW.displayName, "繁體中文")
        XCTAssertEqual(Language.enUS.displayName, "English")
        XCTAssertEqual(Language.ja.displayName, "日本語")
        XCTAssertEqual(Language.de.displayName, "Deutsch")
    }
}
