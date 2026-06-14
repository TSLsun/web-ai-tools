import XCTest
@testable import NewsSummarizer

// MockHTTPSession defined in URLFetcherTests.swift — not redeclared here

final class GeminiClientTests: XCTestCase {
    let testURL = URL(string: "https://example.com/article")!

    func makeClient(responseJSON: String, status: Int = 200) -> GeminiClient {
        let session = MockHTTPSession()
        session.stubbedData = responseJSON.data(using: .utf8)!
        session.stubbedStatus = status
        return GeminiClient(apiKey: "test-key", session: session)
    }

    func testParsesValidGeminiResponse() async throws {
        let innerJSON = #"{"title": "News Title", "bullets": ["Fact 1", "Fact 2"]}"#
        // Build Gemini wrapper response
        let geminiResponse = """
        {
          "candidates": [{
            "content": {
              "parts": [{"text": "\(innerJSON.replacingOccurrences(of: "\"", with: "\\\""))"}]
            }
          }]
        }
        """
        let client = makeClient(responseJSON: geminiResponse)
        let result = try await client.summarize(
            url: testURL,
            cleanText: "article text",
            language: .zhTW
        )
        XCTAssertEqual(result.title, "News Title")
        XCTAssertEqual(result.bullets.count, 2)
    }

    func testThrowsOnEmptyCandidates() async {
        let client = makeClient(responseJSON: #"{"candidates": []}"#)
        do {
            _ = try await client.summarize(url: testURL, cleanText: "text", language: .zhTW)
            XCTFail("Should throw")
        } catch GeminiClientError.emptyResponse {
            // expected
        } catch {
            XCTFail("Wrong error: \(error)")
        }
    }

    func testThrowsOnBadStatus() async {
        let client = makeClient(responseJSON: "{}", status: 429)
        do {
            _ = try await client.summarize(url: testURL, cleanText: "text", language: .zhTW)
            XCTFail("Should throw")
        } catch GeminiClientError.badStatus(let code) {
            XCTAssertEqual(code, 429)
        } catch {
            XCTFail("Wrong error: \(error)")
        }
    }
}
