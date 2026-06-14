import Foundation

enum SummaryPromptBuilder {
    static func build(cleanText: String, language: Language) -> String {
        let truncated = String(cleanText.prefix(4000))
        return """
        Summarize the following article in \(language.rawValue).
        Return ONLY valid JSON with no markdown, no code fences, no extra text:
        {"title": "article title here", "bullets": ["key point 1", "key point 2", "key point 3"]}

        Rules:
        - title: concise headline in \(language.rawValue)
        - bullets: 3 to 5 key facts, no opinions, in \(language.rawValue)
        - JSON only, nothing else

        Article:
        \(truncated)
        """
    }
}
