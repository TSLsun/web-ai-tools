import XCTest
@testable import NewsSummarizer

final class SummaryPromptBuilderTests: XCTestCase {
    func testPromptContainsLanguage() {
        let prompt = SummaryPromptBuilder.build(cleanText: "some text", language: .zhTW)
        XCTAssertTrue(prompt.contains("zh-TW"))
    }

    func testPromptContainsCleanText() {
        let prompt = SummaryPromptBuilder.build(cleanText: "hello world article", language: .enUS)
        XCTAssertTrue(prompt.contains("hello world article"))
    }

    func testPromptRequestsJSON() {
        let prompt = SummaryPromptBuilder.build(cleanText: "text", language: .ja)
        XCTAssertTrue(prompt.contains("JSON"))
    }

    func testLongTextTruncatedAt4000() {
        let longText = String(repeating: "a", count: 6000)
        let prompt = SummaryPromptBuilder.build(cleanText: longText, language: .de)
        let articleRange = prompt.range(of: "Article:\n")!
        let articlePart = String(prompt[articleRange.upperBound...])
        XCTAssertLessThanOrEqual(articlePart.count, 4100)
    }
}
