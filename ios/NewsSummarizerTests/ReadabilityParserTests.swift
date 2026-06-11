import XCTest
import SwiftSoup
@testable import NewsSummarizer

final class ReadabilityParserTests: XCTestCase {
    let sampleHTML = """
    <html>
    <head><title>Page Title</title></head>
    <body>
      <nav>Navigation links</nav>
      <header>Site header</header>
      <article>
        <h1>Real Article Title</h1>
        <p>This is the main article content with important facts.</p>
        <p>Another paragraph with useful information.</p>
      </article>
      <div class="advertisement">Buy now! Ad content here.</div>
      <footer>Footer links</footer>
      <script>alert('js')</script>
    </body>
    </html>
    """

    func testExtractsTitleFromH1() throws {
        let result = try ReadabilityParser.parse(html: sampleHTML)
        XCTAssertEqual(result.title, "Real Article Title")
    }

    func testFallsBackToPageTitle() throws {
        let html = "<html><head><title>Page Title</title></head><body><p>content</p></body></html>"
        let result = try ReadabilityParser.parse(html: html)
        XCTAssertEqual(result.title, "Page Title")
    }

    func testStripsNavAndFooter() throws {
        let result = try ReadabilityParser.parse(html: sampleHTML)
        XCTAssertFalse(result.body.contains("Navigation links"))
        XCTAssertFalse(result.body.contains("Footer links"))
    }

    func testStripsAds() throws {
        let result = try ReadabilityParser.parse(html: sampleHTML)
        XCTAssertFalse(result.body.contains("Buy now"))
    }

    func testStripsScript() throws {
        let result = try ReadabilityParser.parse(html: sampleHTML)
        XCTAssertFalse(result.body.contains("alert"))
    }

    func testKeepsArticleContent() throws {
        let result = try ReadabilityParser.parse(html: sampleHTML)
        XCTAssertTrue(result.body.contains("main article content"))
        XCTAssertTrue(result.body.contains("useful information"))
    }

    func testEmptyBodyReturnsEmptyString() throws {
        let html = "<html><body></body></html>"
        let result = try ReadabilityParser.parse(html: html)
        XCTAssertEqual(result.body, "")
    }
}
