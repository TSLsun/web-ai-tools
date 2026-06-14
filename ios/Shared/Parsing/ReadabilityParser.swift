import Foundation
import SwiftSoup

struct ParsedArticle {
    let title: String
    let body: String
}

enum ReadabilityParser {
    static func parse(html: String) throws -> ParsedArticle {
        let doc = try SwiftSoup.parse(html)

        // Remove noise elements
        let noiseSelectors = "script, style, nav, header, footer, aside, " +
            "[class*='ad'], [class*='advertisement'], [class*='banner'], " +
            "[class*='sidebar'], [class*='related'], [class*='share'], " +
            "[id*='ad'], [id*='sidebar']"
        try doc.select(noiseSelectors).remove()

        // Extract title: h1 first, then <title>
        let title: String
        if let h1 = try doc.select("h1").first() {
            title = try h1.text()
        } else {
            title = try doc.title()
        }

        // Extract body: article > main > [class*=content] > [class*=article] > [class*=post] > body
        let bodySelectors = ["article", "main", "[class*='article']",
                             "[class*='content']", "[class*='post']", "body"]
        var bodyText = ""
        for selector in bodySelectors {
            if let el = try doc.select(selector).first() {
                bodyText = try el.text()
                if bodyText.count > 100 { break }
            }
        }

        return ParsedArticle(title: title, body: bodyText)
    }
}
