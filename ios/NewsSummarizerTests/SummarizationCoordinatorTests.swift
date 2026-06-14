import XCTest
@testable import NewsSummarizer

final class SummarizationCoordinatorTests: XCTestCase {
    let testURL = URL(string: "https://example.com/article")!
    let sampleHTML = "<html><body><article><h1>Test</h1><p>Content here</p></article></body></html>"
    let fakeSummary = SummaryResult(
        title: "Test",
        bullets: ["Point 1"],
        url: URL(string: "https://example.com")!
    )

    func testUsesMacClientWhenAvailable() async throws {
        var macCalled = false
        let coordinator = SummarizationCoordinator(
            fetcher: StaticFetcher(html: sampleHTML),
            macClient: { _, _, _ in macCalled = true; return self.fakeSummary },
            geminiClient: { _, _, _ in XCTFail("Gemini should not be called"); return self.fakeSummary }
        )
        let result = try await coordinator.summarize(url: testURL, language: .zhTW)
        XCTAssertTrue(macCalled)
        XCTAssertEqual(result.title, "Test")
    }

    func testFallsBackToGeminiWhenMacFails() async throws {
        var geminiCalled = false
        let coordinator = SummarizationCoordinator(
            fetcher: StaticFetcher(html: sampleHTML),
            macClient: { _, _, _ in throw URLError(.timedOut) },
            geminiClient: { _, _, _ in geminiCalled = true; return self.fakeSummary }
        )
        let result = try await coordinator.summarize(url: testURL, language: .zhTW)
        XCTAssertTrue(geminiCalled)
        XCTAssertEqual(result.title, "Test")
    }

    func testThrowsWhenBothFail() async {
        let coordinator = SummarizationCoordinator(
            fetcher: StaticFetcher(html: sampleHTML),
            macClient: { _, _, _ in throw URLError(.timedOut) },
            geminiClient: { _, _, _ in throw GeminiClientError.emptyResponse }
        )
        do {
            _ = try await coordinator.summarize(url: testURL, language: .zhTW)
            XCTFail("Should throw")
        } catch CoordinatorError.allBackendsFailed {
            // expected
        } catch {
            XCTFail("Wrong error: \(error)")
        }
    }
}

// MARK: - Test helpers
private struct StaticFetcher: FetcherProtocol {
    let html: String
    func fetch(_ url: URL) async throws -> String { html }
}
