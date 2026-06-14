import XCTest
@testable import NewsSummarizer

// MockHTTPSession is defined in URLFetcherTests.swift — DO NOT redeclare it here

final class MacClientTests: XCTestCase {
    let testURL = URL(string: "https://example.com/article")!

    func makeClient(responseJSON: String, status: Int = 200) -> MacClient {
        let session = MockHTTPSession()
        session.stubbedData = responseJSON.data(using: .utf8)!
        session.stubbedStatus = status
        return MacClient(
            serverURL: URL(string: "http://100.64.0.1:8765/summarize")!,
            sharedSecret: "test-secret",
            session: session
        )
    }

    func testReturnsValidSummary() async throws {
        let json = """
        {"title": "Test Title", "bullets": ["Point 1", "Point 2", "Point 3"], "url": "https://example.com"}
        """
        let client = makeClient(responseJSON: json)
        let result = try await client.summarize(
            url: testURL,
            cleanText: "article text",
            language: .zhTW
        )
        XCTAssertEqual(result.title, "Test Title")
        XCTAssertEqual(result.bullets.count, 3)
        XCTAssertEqual(result.bullets[0], "Point 1")
    }

    func testThrowsOn401() async {
        let client = makeClient(responseJSON: "{\"error\": \"unauthorized\"}", status: 401)
        do {
            _ = try await client.summarize(url: testURL, cleanText: "text", language: .zhTW)
            XCTFail("Should throw")
        } catch MacClientError.unauthorized {
            // expected
        } catch {
            XCTFail("Wrong error: \(error)")
        }
    }

    func testThrowsOnNetworkError() async {
        let session = MockHTTPSession()
        session.stubbedError = URLError(.timedOut)
        let client = MacClient(
            serverURL: URL(string: "http://100.64.0.1:8765/summarize")!,
            sharedSecret: "secret",
            session: session
        )
        do {
            _ = try await client.summarize(url: testURL, cleanText: "text", language: .zhTW)
            XCTFail("Should throw")
        } catch {
            // any error — timeout propagated
        }
    }
}
