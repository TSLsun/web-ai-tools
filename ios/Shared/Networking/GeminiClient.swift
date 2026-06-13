import Foundation

enum GeminiClientError: LocalizedError {
    case badStatus(Int)
    case emptyResponse
    case parseError

    var errorDescription: String? {
        switch self {
        case .badStatus(let code): return "Gemini HTTP \(code) — check API key or quota"
        case .emptyResponse: return "Gemini returned empty response"
        case .parseError: return "Gemini response parse failed"
        }
    }
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
            let body = String(data: data, encoding: .utf8) ?? "<non-utf8>"
            print("[GeminiClient] HTTP \(http.statusCode): \(body.prefix(500))")
            throw GeminiClientError.badStatus(http.statusCode)
        }

        let gemini = try JSONDecoder().decode(GeminiResponse.self, from: data)
        guard let text = gemini.candidates.first?.content.parts.first?.text else {
            throw GeminiClientError.emptyResponse
        }

        guard let textData = text.data(using: .utf8) else {
            throw GeminiClientError.parseError
        }
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
