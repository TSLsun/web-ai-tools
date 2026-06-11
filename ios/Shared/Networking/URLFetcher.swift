import Foundation

enum URLFetcherError: Error {
    case badResponse
    case decodingFailed
}

struct URLFetcher {
    private let session: HTTPSession

    init(session: HTTPSession = URLSession.shared) {
        self.session = session
    }

    func fetch(_ url: URL) async throws -> String {
        var request = URLRequest(url: url, timeoutInterval: 10)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLFetcherError.badResponse
        }
        if let html = String(data: data, encoding: .utf8) { return html }
        if let html = String(data: data, encoding: .isoLatin1) { return html }
        throw URLFetcherError.decodingFailed
    }
}

protocol FetcherProtocol {
    func fetch(_ url: URL) async throws -> String
}

extension URLFetcher: FetcherProtocol {}
