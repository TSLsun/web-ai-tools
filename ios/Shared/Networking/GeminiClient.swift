import Foundation

enum GeminiClientError: Error {
    case badStatus(Int)
    case emptyResponse
    case parseError
}

struct GeminiClient {
    private let apiKey: String
    private let session: HTTPSession
    private let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent"

    init(apiKey: String, session: HTTPSession = URLSession.shared) {
        self.apiKey = apiKey
        self.session = session
    }

    func summarize(url: URL, cleanText: String, language: Language) async throws -> SummaryResult {
        guard let requestURL = URL(string: "\(endpoint)?key=\(apiKey)") else {
            throw GeminiClientError.parseError
        }

        var request = URLRequest(url: requestURL, timeoutInterval: 15)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let prompt = SummaryPromptBuilder.build(cleanText: cleanText, language: language)
        let body: [String: Any] = [
            "contents": [["parts": [["text": prompt]]]],
            "generationConfig": ["responseMimeType": "application/json"]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)

        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw GeminiClientError.badStatus(http.statusCode)
        }

        let gemini = try JSONDecoder().decode(GeminiResponse.self, from: data)
        guard let text = gemini.candidates.first?.content.parts.first?.text else {
            throw GeminiClientError.emptyResponse
        }

        let textData = text.data(using: .utf8) ?? Data()
        let parsed = try JSONDecoder().decode(SummaryJSON.self, from: textData)

        return SummaryResult(title: parsed.title, bullets: parsed.bullets, url: url)
    }

    // MARK: - Response types
    private struct GeminiResponse: Decodable {
        let candidates: [Candidate]
        struct Candidate: Decodable {
            let content: Content
            struct Content: Decodable {
                let parts: [Part]
                struct Part: Decodable {
                    let text: String
                }
            }
        }
    }

    private struct SummaryJSON: Decodable {
        let title: String
        let bullets: [String]
    }
}
