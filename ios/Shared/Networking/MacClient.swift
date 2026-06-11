import Foundation

enum MacClientError: Error {
    case unauthorized
    case invalidResponse
}

struct MacClient {
    private let serverURL: URL
    private let sharedSecret: String
    private let session: HTTPSession

    init(serverURL: URL, sharedSecret: String, session: HTTPSession = URLSession.shared) {
        self.serverURL = serverURL
        self.sharedSecret = sharedSecret
        self.session = session
    }

    func summarize(url: URL, cleanText: String, language: Language) async throws -> SummaryResult {
        var request = URLRequest(url: serverURL, timeoutInterval: 3)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(sharedSecret, forHTTPHeaderField: "X-Secret")

        let body: [String: String] = [
            "url": url.absoluteString,
            "cleanText": cleanText,
            "language": language.rawValue
        ]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)

        if let http = response as? HTTPURLResponse, http.statusCode == 401 {
            throw MacClientError.unauthorized
        }

        do {
            let decoded = try JSONDecoder().decode(MacResponse.self, from: data)
            return SummaryResult(
                title: decoded.title,
                bullets: decoded.bullets,
                url: URL(string: decoded.url) ?? url
            )
        } catch is DecodingError {
            throw MacClientError.invalidResponse
        }
    }

    private struct MacResponse: Decodable {
        let title: String
        let bullets: [String]
        let url: String
    }
}
