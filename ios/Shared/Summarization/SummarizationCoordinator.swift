import Foundation

enum CoordinatorError: Error {
    case allBackendsFailed
    case noURL
}

final class SummarizationCoordinator {
    typealias SummaryFn = (URL, String, Language) async throws -> SummaryResult

    private let fetcher: FetcherProtocol
    private let macClient: SummaryFn?
    private let geminiClient: SummaryFn?

    init(fetcher: FetcherProtocol = URLFetcher(),
         macClient: SummaryFn? = nil,
         geminiClient: SummaryFn? = nil) {
        self.fetcher = fetcher
        self.macClient = macClient
        self.geminiClient = geminiClient
    }

    static func make(settings: SettingsStore) -> SummarizationCoordinator {
        let macFn: SummaryFn? = settings.macServerURL.map { url in
            let client = MacClient(serverURL: url, sharedSecret: settings.sharedSecret)
            return { articleURL, cleanText, lang in
                try await client.summarize(url: articleURL, cleanText: cleanText, language: lang)
            }
        }
        let geminiFn: SummaryFn? = settings.geminiAPIKey.isEmpty ? nil : { url, cleanText, lang in
            let client = GeminiClient(apiKey: settings.geminiAPIKey)
            return try await client.summarize(url: url, cleanText: cleanText, language: lang)
        }
        return SummarizationCoordinator(macClient: macFn, geminiClient: geminiFn)
    }

    func summarize(url: URL, language: Language) async throws -> SummaryResult {
        let html = try await fetcher.fetch(url)
        let parsed = try ReadabilityParser.parse(html: html)
        let cleanText = parsed.body.isEmpty ? html : parsed.body
        let title = parsed.title

        if let mac = macClient {
            do {
                let result = try await mac(url, cleanText, language)
                return SummaryResult(
                    title: result.title.isEmpty ? title : result.title,
                    bullets: result.bullets,
                    url: url
                )
            } catch {
                print("[Coordinator] Mac backend failed: \(error)")
            }
        }

        if let gemini = geminiClient {
            do {
                let result = try await gemini(url, cleanText, language)
                return SummaryResult(
                    title: result.title.isEmpty ? title : result.title,
                    bullets: result.bullets,
                    url: url
                )
            } catch {
                print("[Coordinator] Gemini backend failed: \(error)")
                throw error
            }
        }

        throw CoordinatorError.allBackendsFailed
    }
}
