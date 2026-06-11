import XCTest
@testable import NewsSummarizer

final class MockHTTPSession: HTTPSession {
    var stubbedData: Data = Data()
    var stubbedStatus: Int = 200
    var stubbedError: Error?

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        if let error = stubbedError { throw error }
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: stubbedStatus,
            httpVersion: nil,
            headerFields: nil
        )!
        return (stubbedData, response)
    }
}

final class URLFetcherTests: XCTestCase {
    func testFetchReturnsHTMLString() async throws {
        let session = MockHTTPSession()
        session.stubbedData = "<html><body>Hello</body></html>".data(using: .utf8)!
        let fetcher = URLFetcher(session: session)
        let result = try await fetcher.fetch(URL(string: "https://example.com")!)
        XCTAssertEqual(result, "<html><body>Hello</body></html>")
    }

    func testFetchThrowsOn404() async {
        let session = MockHTTPSession()
        session.stubbedStatus = 404
        let fetcher = URLFetcher(session: session)
        do {
            _ = try await fetcher.fetch(URL(string: "https://example.com")!)
            XCTFail("Should have thrown")
        } catch URLFetcherError.badResponse {
            // expected
        } catch {
            XCTFail("Wrong error: \(error)")
        }
    }

    func testFetchThrowsOnNetworkError() async {
        let session = MockHTTPSession()
        session.stubbedError = URLError(.notConnectedToInternet)
        let fetcher = URLFetcher(session: session)
        do {
            _ = try await fetcher.fetch(URL(string: "https://example.com")!)
            XCTFail("Should have thrown")
        } catch {
            // any error is fine — network error propagated
        }
    }
}
