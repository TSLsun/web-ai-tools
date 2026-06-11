# iOS News Summarizer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native iOS Share Extension that cleans article content via SwiftSoup, summarizes via Mac HTTP server over Tailscale (primary, uses `claude -p` CLI) or Gemini Flash free API (fallback), and displays structured results inline in the share sheet.

**Architecture:** Two Xcode targets (main app = settings UI only; share extension = full flow) share `Shared/` source files via dual target membership and an App Group container. Mac runs a Python HTTP server auto-started by a LaunchAgent, reachable privately through Tailscale.

**Tech Stack:** Swift 5.9+, SwiftUI, XCTest, SwiftSoup (SPM), URLSession, Keychain Services, iOS 16+, Python 3 (Mac server), Tailscale (WireGuard VPN, free personal)

---

## Pre-requisites (one-time manual setup, not part of tasks)

Before starting tasks, complete these manually:

1. Install `xcodegen`: `brew install xcodegen`
2. Install Tailscale on Mac and iPhone (free at tailscale.com) — join same tailnet
3. Note your Mac's Tailscale IP: run `tailscale ip -4` on Mac
4. Get free Gemini API key from [Google AI Studio](https://aistudio.google.com/app/apikey)
5. Generate a shared secret token: `openssl rand -hex 32`

---

## File Map

```
web-ai-tools/
├── ios/                              # iOS Xcode project root
│   ├── project.yml                   # xcodegen spec
│   ├── NewsSummarizer/               # Main App target sources
│   │   ├── NewsSummarizerApp.swift
│   │   └── SettingsView.swift
│   ├── ShareExtension/               # Share Extension target sources
│   │   ├── Info.plist
│   │   ├── ShareViewController.swift
│   │   ├── ShareRootView.swift
│   │   └── Views/
│   │       ├── LoadingView.swift
│   │       └── SummaryView.swift
│   ├── Shared/                       # Source files in BOTH targets
│   │   ├── Models/
│   │   │   ├── SummaryResult.swift
│   │   │   └── Language.swift
│   │   ├── Storage/
│   │   │   ├── KeychainHelper.swift
│   │   │   └── SettingsStore.swift
│   │   ├── Networking/
│   │   │   ├── HTTPSession.swift     # protocol for mocking URLSession
│   │   │   ├── URLFetcher.swift
│   │   │   ├── MacClient.swift
│   │   │   └── GeminiClient.swift
│   │   ├── Parsing/
│   │   │   └── ReadabilityParser.swift
│   │   ├── Prompt/
│   │   │   └── SummaryPromptBuilder.swift
│   │   └── Summarization/
│   │       └── SummarizationCoordinator.swift  # Shared so tests can reach it
│   └── NewsSummarizerTests/          # Unit tests (main app target)
│       ├── LanguageTests.swift
│       ├── SettingsStoreTests.swift
│       ├── SummaryPromptBuilderTests.swift
│       ├── URLFetcherTests.swift
│       ├── ReadabilityParserTests.swift
│       ├── MacClientTests.swift
│       ├── GeminiClientTests.swift
│       └── SummarizationCoordinatorTests.swift
└── mac-server/
    ├── server.py
    ├── setup.sh                      # installs LaunchAgent
    └── config.example.json
```

---

## Task 1: Scaffold Xcode project with xcodegen

**Files:**
- Create: `ios/project.yml`
- Create: `ios/NewsSummarizer/NewsSummarizerApp.swift` (stub)
- Create: `ios/ShareExtension/Info.plist`

- [ ] **Step 1: Create project.yml**

```yaml
# ios/project.yml
name: NewsSummarizer
options:
  bundleIdPrefix: com.tslsun
  deploymentTarget:
    iOS: "16.0"

packages:
  SwiftSoup:
    url: https://github.com/scinfu/SwiftSoup
    from: 2.7.2

targets:
  NewsSummarizer:
    type: application
    platform: iOS
    sources:
      - path: NewsSummarizer
      - path: Shared
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.tslsun.newssummarizer
        SWIFT_VERSION: "5.9"
    entitlements:
      path: NewsSummarizer/NewsSummarizer.entitlements
      properties:
        com.apple.security.application-groups:
          - group.com.tslsun.newssummarizer
    dependencies:
      - package: SwiftSoup
    info:
      path: NewsSummarizer/Info.plist
      properties:
        UILaunchScreen: {}

  ShareExtension:
    type: app-extension
    platform: iOS
    sources:
      - path: ShareExtension
      - path: Shared
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.tslsun.newssummarizer.shareextension
        SWIFT_VERSION: "5.9"
    entitlements:
      path: ShareExtension/ShareExtension.entitlements
      properties:
        com.apple.security.application-groups:
          - group.com.tslsun.newssummarizer
    dependencies:
      - package: SwiftSoup
      - target: NewsSummarizer
        embed: false
    info:
      path: ShareExtension/Info.plist
      properties:
        NSExtension:
          NSExtensionPointIdentifier: com.apple.share-services
          NSExtensionPrincipalClass: $(PRODUCT_MODULE_NAME).ShareViewController
          NSExtensionActivationRule:
            NSExtensionActivationSupportsWebURLWithMaxCount: 1

  NewsSummarizerTests:
    type: bundle.unit-test
    platform: iOS
    sources:
      - path: NewsSummarizerTests
    settings:
      base:
        SWIFT_VERSION: "5.9"
    dependencies:
      - target: NewsSummarizer  # Shared/ types accessible via @testable import NewsSummarizer
      - package: SwiftSoup
```

- [ ] **Step 2: Create stub app entry point**

```swift
// ios/NewsSummarizer/NewsSummarizerApp.swift
import SwiftUI

@main
struct NewsSummarizerApp: App {
    var body: some Scene {
        WindowGroup {
            SettingsView()
        }
    }
}
```

- [ ] **Step 3: Create Share Extension Info.plist stub** (xcodegen generates it, but create directory)

```bash
mkdir -p ios/NewsSummarizer ios/ShareExtension ios/Shared/Models ios/Shared/Storage ios/Shared/Networking ios/Shared/Parsing ios/Shared/Prompt ios/NewsSummarizerTests
```

- [ ] **Step 4: Generate Xcode project**

```bash
cd ios && xcodegen generate
```

Expected: `NewsSummarizer.xcodeproj` created with no errors.

- [ ] **Step 5: Verify project opens**

```bash
open ios/NewsSummarizer.xcodeproj
```

Expected: Xcode opens, two app targets visible (NewsSummarizer, ShareExtension), tests target visible.

- [ ] **Step 6: Commit**

```bash
git add ios/project.yml ios/NewsSummarizer/NewsSummarizerApp.swift
git commit -m "feat: scaffold iOS project with xcodegen"
```

---

## Task 2: Models — SummaryResult and Language

**Files:**
- Create: `ios/Shared/Models/SummaryResult.swift`
- Create: `ios/Shared/Models/Language.swift`
- Create: `ios/NewsSummarizerTests/LanguageTests.swift`

- [ ] **Step 1: Write failing test**

```swift
// ios/NewsSummarizerTests/LanguageTests.swift
import XCTest
@testable import NewsSummarizer

final class LanguageTests: XCTestCase {
    func testAllCasesPresent() {
        XCTAssertEqual(Language.allCases.count, 4)
    }

    func testRawValues() {
        XCTAssertEqual(Language.zhTW.rawValue, "zh-TW")
        XCTAssertEqual(Language.enUS.rawValue, "en-US")
        XCTAssertEqual(Language.ja.rawValue, "ja")
        XCTAssertEqual(Language.de.rawValue, "de")
    }

    func testDefaultIsZhTW() {
        XCTAssertEqual(Language.default, .zhTW)
    }

    func testDisplayNames() {
        XCTAssertEqual(Language.zhTW.displayName, "繁體中文")
        XCTAssertEqual(Language.enUS.displayName, "English")
        XCTAssertEqual(Language.ja.displayName, "日本語")
        XCTAssertEqual(Language.de.displayName, "Deutsch")
    }
}
```

- [ ] **Step 2: Run test — verify FAIL**

In Xcode: Product → Test (⌘U). Expected: compile error "cannot find type Language".

- [ ] **Step 3: Implement Language**

```swift
// ios/Shared/Models/Language.swift
import Foundation

enum Language: String, CaseIterable, Codable {
    case zhTW = "zh-TW"
    case enUS = "en-US"
    case ja = "ja"
    case de = "de"

    static let `default`: Language = .zhTW

    var displayName: String {
        switch self {
        case .zhTW: return "繁體中文"
        case .enUS: return "English"
        case .ja: return "日本語"
        case .de: return "Deutsch"
        }
    }
}
```

- [ ] **Step 4: Implement SummaryResult**

```swift
// ios/Shared/Models/SummaryResult.swift
import Foundation

struct SummaryResult {
    let title: String
    let bullets: [String]
    let url: URL
}
```

- [ ] **Step 5: Run tests — verify PASS**

Expected: LanguageTests — 4 tests pass.

- [ ] **Step 6: Commit**

```bash
git add ios/Shared/Models/ ios/NewsSummarizerTests/LanguageTests.swift
git commit -m "feat: add SummaryResult and Language models"
```

---

## Task 3: SettingsStore

**Files:**
- Create: `ios/Shared/Storage/KeychainHelper.swift`
- Create: `ios/Shared/Storage/SettingsStore.swift`
- Create: `ios/NewsSummarizerTests/SettingsStoreTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
// ios/NewsSummarizerTests/SettingsStoreTests.swift
import XCTest
@testable import NewsSummarizer

final class SettingsStoreTests: XCTestCase {
    var store: SettingsStore!

    override func setUp() {
        super.setUp()
        // Use in-memory UserDefaults for tests (no suite name = ephemeral)
        store = SettingsStore(defaults: UserDefaults(suiteName: "test-\(UUID().uuidString)")!)
    }

    func testLanguageDefaultIsZhTW() {
        XCTAssertEqual(store.language, .zhTW)
    }

    func testLanguagePersists() {
        store.language = .enUS
        XCTAssertEqual(store.language, .enUS)
    }

    func testMacIPDefaultIsEmpty() {
        XCTAssertEqual(store.macTailscaleIP, "")
    }

    func testMacIPPersists() {
        store.macTailscaleIP = "100.64.0.1"
        XCTAssertEqual(store.macTailscaleIP, "100.64.0.1")
    }

    func testIsConfiguredFalseWhenEmpty() {
        XCTAssertFalse(store.isConfigured)
    }

    func testIsConfiguredTrueWhenMacIPAndGeminiSet() {
        store.macTailscaleIP = "100.64.0.1"
        store.geminiAPIKey = "test-key"
        XCTAssertTrue(store.isConfigured)
    }
}
```

- [ ] **Step 2: Run test — verify FAIL**

Expected: compile error "cannot find type SettingsStore".

- [ ] **Step 3: Implement KeychainHelper**

```swift
// ios/Shared/Storage/KeychainHelper.swift
import Foundation
import Security

struct KeychainHelper {
    private let service: String
    private let accessGroup: String

    init(service: String = "com.tslsun.newssummarizer",
         accessGroup: String = "group.com.tslsun.newssummarizer") {
        self.service = service
        self.accessGroup = accessGroup
    }

    func set(_ value: String, for key: String) {
        let data = value.data(using: .utf8)!
        var query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
            kSecAttrAccessGroup: accessGroup,
        ]
        SecItemDelete(query as CFDictionary)
        query[kSecValueData] = data
        SecItemAdd(query as CFDictionary, nil)
    }

    func get(_ key: String) -> String {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
            kSecAttrAccessGroup: accessGroup,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else { return "" }
        return string
    }

    func delete(_ key: String) {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
            kSecAttrAccessGroup: accessGroup,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
```

- [ ] **Step 4: Implement SettingsStore**

```swift
// ios/Shared/Storage/SettingsStore.swift
import Foundation

final class SettingsStore: ObservableObject {
    private let defaults: UserDefaults
    private let keychain: KeychainHelper

    init(defaults: UserDefaults = UserDefaults(suiteName: "group.com.tslsun.newssummarizer")!,
         keychain: KeychainHelper = KeychainHelper()) {
        self.defaults = defaults
        self.keychain = keychain
    }

    var language: Language {
        get {
            guard let raw = defaults.string(forKey: "language"),
                  let lang = Language(rawValue: raw) else { return .default }
            return lang
        }
        set {
            defaults.set(newValue.rawValue, forKey: "language")
            objectWillChange.send()
        }
    }

    var macTailscaleIP: String {
        get { defaults.string(forKey: "macTailscaleIP") ?? "" }
        set {
            defaults.set(newValue, forKey: "macTailscaleIP")
            objectWillChange.send()
        }
    }

    var sharedSecret: String {
        get { keychain.get("sharedSecret") }
        set { keychain.set(newValue, for: "sharedSecret") }
    }

    var geminiAPIKey: String {
        get { keychain.get("geminiAPIKey") }
        set { keychain.set(newValue, for: "geminiAPIKey") }
    }

    var isConfigured: Bool {
        !macTailscaleIP.isEmpty || !geminiAPIKey.isEmpty
    }

    var macServerURL: URL? {
        guard !macTailscaleIP.isEmpty else { return nil }
        return URL(string: "http://\(macTailscaleIP):8765/summarize")
    }
}
```

- [ ] **Step 5: Run tests — verify PASS**

Expected: SettingsStoreTests — 6 tests pass.

- [ ] **Step 6: Commit**

```bash
git add ios/Shared/Storage/ ios/NewsSummarizerTests/SettingsStoreTests.swift
git commit -m "feat: add SettingsStore with Keychain and UserDefaults"
```

---

## Task 4: SummaryPromptBuilder

**Files:**
- Create: `ios/Shared/Prompt/SummaryPromptBuilder.swift`
- Create: `ios/NewsSummarizerTests/SummaryPromptBuilderTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
// ios/NewsSummarizerTests/SummaryPromptBuilderTests.swift
import XCTest
@testable import NewsSummarizer

final class SummaryPromptBuilderTests: XCTestCase {
    func testPromptContainsLanguage() {
        let prompt = SummaryPromptBuilder.build(cleanText: "some text", language: .zhTW)
        XCTAssertTrue(prompt.contains("zh-TW"))
    }

    func testPromptContainsCleanText() {
        let prompt = SummaryPromptBuilder.build(cleanText: "hello world article", language: .enUS)
        XCTAssertTrue(prompt.contains("hello world article"))
    }

    func testPromptRequestsJSON() {
        let prompt = SummaryPromptBuilder.build(cleanText: "text", language: .ja)
        XCTAssertTrue(prompt.contains("JSON"))
    }

    func testLongTextTruncatedAt4000() {
        let longText = String(repeating: "a", count: 6000)
        let prompt = SummaryPromptBuilder.build(cleanText: longText, language: .de)
        // prompt itself > 4000 but cleanText portion should be truncated
        let articleRange = prompt.range(of: "Article:\n")!
        let articlePart = String(prompt[articleRange.upperBound...])
        XCTAssertLessThanOrEqual(articlePart.count, 4100) // some tolerance for trailing chars
    }
}
```

- [ ] **Step 2: Run test — verify FAIL**

Expected: compile error "cannot find SummaryPromptBuilder".

- [ ] **Step 3: Implement SummaryPromptBuilder**

```swift
// ios/Shared/Prompt/SummaryPromptBuilder.swift
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
```

- [ ] **Step 4: Run tests — verify PASS**

Expected: SummaryPromptBuilderTests — 4 tests pass.

- [ ] **Step 5: Commit**

```bash
git add ios/Shared/Prompt/ ios/NewsSummarizerTests/SummaryPromptBuilderTests.swift
git commit -m "feat: add SummaryPromptBuilder"
```

---

## Task 5: HTTPSession protocol + URLFetcher

**Files:**
- Create: `ios/Shared/Networking/HTTPSession.swift`
- Create: `ios/Shared/Networking/URLFetcher.swift`
- Create: `ios/NewsSummarizerTests/URLFetcherTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
// ios/NewsSummarizerTests/URLFetcherTests.swift
import XCTest
@testable import NewsSummarizer

// Test double lives in the test file
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
```

- [ ] **Step 2: Run test — verify FAIL**

Expected: compile error "cannot find HTTPSession / URLFetcher".

- [ ] **Step 3: Implement HTTPSession protocol**

```swift
// ios/Shared/Networking/HTTPSession.swift
import Foundation

protocol HTTPSession {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: HTTPSession {}
```

- [ ] **Step 4: Implement URLFetcher**

```swift
// ios/Shared/Networking/URLFetcher.swift
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
```

- [ ] **Step 5: Run tests — verify PASS**

Expected: URLFetcherTests — 3 tests pass.

- [ ] **Step 6: Commit**

```bash
git add ios/Shared/Networking/HTTPSession.swift ios/Shared/Networking/URLFetcher.swift ios/NewsSummarizerTests/URLFetcherTests.swift
git commit -m "feat: add URLFetcher with protocol-based session for testability"
```

---

## Task 6: ReadabilityParser

**Files:**
- Create: `ios/Shared/Parsing/ReadabilityParser.swift`
- Create: `ios/NewsSummarizerTests/ReadabilityParserTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
// ios/NewsSummarizerTests/ReadabilityParserTests.swift
import XCTest
import SwiftSoup
@testable import NewsSummarizer

final class ReadabilityParserTests: XCTestCase {
    let sampleHTML = """
    <html>
    <head><title>Page Title</title></head>
    <body>
      <nav>Navigation links</nav>
      <header>Site header</header>
      <article>
        <h1>Real Article Title</h1>
        <p>This is the main article content with important facts.</p>
        <p>Another paragraph with useful information.</p>
      </article>
      <div class="advertisement">Buy now! Ad content here.</div>
      <footer>Footer links</footer>
      <script>alert('js')</script>
    </body>
    </html>
    """

    func testExtractsTitleFromH1() throws {
        let result = try ReadabilityParser.parse(html: sampleHTML)
        XCTAssertEqual(result.title, "Real Article Title")
    }

    func testFallsBackToPageTitle() throws {
        let html = "<html><head><title>Page Title</title></head><body><p>content</p></body></html>"
        let result = try ReadabilityParser.parse(html: html)
        XCTAssertEqual(result.title, "Page Title")
    }

    func testStripsNavAndFooter() throws {
        let result = try ReadabilityParser.parse(html: sampleHTML)
        XCTAssertFalse(result.body.contains("Navigation links"))
        XCTAssertFalse(result.body.contains("Footer links"))
    }

    func testStripsAds() throws {
        let result = try ReadabilityParser.parse(html: sampleHTML)
        XCTAssertFalse(result.body.contains("Buy now"))
    }

    func testStripsScript() throws {
        let result = try ReadabilityParser.parse(html: sampleHTML)
        XCTAssertFalse(result.body.contains("alert"))
    }

    func testKeepsArticleContent() throws {
        let result = try ReadabilityParser.parse(html: sampleHTML)
        XCTAssertTrue(result.body.contains("main article content"))
        XCTAssertTrue(result.body.contains("useful information"))
    }

    func testEmptyBodyReturnsEmptyString() throws {
        let html = "<html><body></body></html>"
        let result = try ReadabilityParser.parse(html: html)
        XCTAssertEqual(result.body, "")
    }
}
```

- [ ] **Step 2: Run test — verify FAIL**

Expected: compile error "cannot find ReadabilityParser".

- [ ] **Step 3: Implement ReadabilityParser**

```swift
// ios/Shared/Parsing/ReadabilityParser.swift
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

        // Extract body: article > main > [class*=content] > body
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
```

- [ ] **Step 4: Run tests — verify PASS**

Expected: ReadabilityParserTests — 7 tests pass.

- [ ] **Step 5: Commit**

```bash
git add ios/Shared/Parsing/ ios/NewsSummarizerTests/ReadabilityParserTests.swift
git commit -m "feat: add ReadabilityParser with SwiftSoup"
```

---

## Task 7: MacClient

**Files:**
- Create: `ios/Shared/Networking/MacClient.swift`
- Create: `ios/NewsSummarizerTests/MacClientTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
// ios/NewsSummarizerTests/MacClientTests.swift
import XCTest
@testable import NewsSummarizer

final class MacClientTests: XCTestCase {
    let testURL = URL(string: "https://example.com/article")!

    func makeClient(responseJSON: String, status: Int = 200) -> MacClient {
        let session = MockHTTPSession()
        session.stubbedData = responseJSON.data(using: .utf8)!
        session.stubbedStatus = status
        return MacClient(
            serverURL: URL(string: "http://100.64.0.1:8765/summarize")!,
            sharedSecret: "test-secret",
            session: session
        )
    }

    func testReturnsValidSummary() async throws {
        let json = """
        {"title": "Test Title", "bullets": ["Point 1", "Point 2", "Point 3"], "url": "https://example.com"}
        """
        let client = makeClient(responseJSON: json)
        let result = try await client.summarize(
            url: testURL,
            cleanText: "article text",
            language: .zhTW
        )
        XCTAssertEqual(result.title, "Test Title")
        XCTAssertEqual(result.bullets.count, 3)
        XCTAssertEqual(result.bullets[0], "Point 1")
    }

    func testThrowsOn401() async {
        let client = makeClient(responseJSON: "{\"error\": \"unauthorized\"}", status: 401)
        do {
            _ = try await client.summarize(url: testURL, cleanText: "text", language: .zhTW)
            XCTFail("Should throw")
        } catch MacClientError.unauthorized {
            // expected
        } catch {
            XCTFail("Wrong error: \(error)")
        }
    }

    func testThrowsOnNetworkError() async {
        let session = MockHTTPSession()
        session.stubbedError = URLError(.timedOut)
        let client = MacClient(
            serverURL: URL(string: "http://100.64.0.1:8765/summarize")!,
            sharedSecret: "secret",
            session: session
        )
        do {
            _ = try await client.summarize(url: testURL, cleanText: "text", language: .zhTW)
            XCTFail("Should throw")
        } catch {
            // any error — timeout propagated
        }
    }
}
```

- [ ] **Step 2: Run test — verify FAIL**

Expected: compile error "cannot find MacClient".

- [ ] **Step 3: Implement MacClient**

```swift
// ios/Shared/Networking/MacClient.swift
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

        let decoded = try JSONDecoder().decode(MacResponse.self, from: data)
        return SummaryResult(
            title: decoded.title,
            bullets: decoded.bullets,
            url: URL(string: decoded.url) ?? url
        )
    }

    private struct MacResponse: Decodable {
        let title: String
        let bullets: [String]
        let url: String
    }
}
```

- [ ] **Step 4: Run tests — verify PASS**

Expected: MacClientTests — 3 tests pass.

- [ ] **Step 5: Commit**

```bash
git add ios/Shared/Networking/MacClient.swift ios/NewsSummarizerTests/MacClientTests.swift
git commit -m "feat: add MacClient for Tailscale Mac server communication"
```

---

## Task 8: GeminiClient

**Files:**
- Create: `ios/Shared/Networking/GeminiClient.swift`
- Create: `ios/NewsSummarizerTests/GeminiClientTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
// ios/NewsSummarizerTests/GeminiClientTests.swift
import XCTest
@testable import NewsSummarizer

final class GeminiClientTests: XCTestCase {
    let testURL = URL(string: "https://example.com/article")!

    func makeClient(responseJSON: String, status: Int = 200) -> GeminiClient {
        let session = MockHTTPSession()
        session.stubbedData = responseJSON.data(using: .utf8)!
        session.stubbedStatus = status
        return GeminiClient(apiKey: "test-key", session: session)
    }

    func testParsesValidGeminiResponse() async throws {
        // Gemini wraps response in candidates array
        let innerJSON = #"{"title": "News Title", "bullets": ["Fact 1", "Fact 2"]}"#
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
```

- [ ] **Step 2: Run test — verify FAIL**

Expected: compile error "cannot find GeminiClient".

- [ ] **Step 3: Implement GeminiClient**

```swift
// ios/Shared/Networking/GeminiClient.swift
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
```

- [ ] **Step 4: Run tests — verify PASS**

Expected: GeminiClientTests — 3 tests pass.

- [ ] **Step 5: Commit**

```bash
git add ios/Shared/Networking/GeminiClient.swift ios/NewsSummarizerTests/GeminiClientTests.swift
git commit -m "feat: add GeminiClient for Gemini Flash fallback"
```

---

## Task 9: SummarizationCoordinator

**Files:**
- Create: `ios/Shared/Summarization/SummarizationCoordinator.swift`
- Create: `ios/NewsSummarizerTests/SummarizationCoordinatorTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
// ios/NewsSummarizerTests/SummarizationCoordinatorTests.swift
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

    func testUseMacClientWhenAvailable() async throws {
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
```

- [ ] **Step 2: Run test — verify FAIL**

Expected: compile errors for SummarizationCoordinator, FetcherProtocol, CoordinatorError.

- [ ] **Step 3: Add FetcherProtocol to URLFetcher.swift**

```swift
// Add to bottom of ios/Shared/Networking/URLFetcher.swift
protocol FetcherProtocol {
    func fetch(_ url: URL) async throws -> String
}

extension URLFetcher: FetcherProtocol {}
```

- [ ] **Step 4: Implement SummarizationCoordinator**

```swift
// ios/ShareExtension/SummarizationCoordinator.swift
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

        // Try Mac server first
        if let mac = macClient {
            if let result = try? await mac(url, cleanText, language) {
                return SummaryResult(title: result.title.isEmpty ? title : result.title,
                                     bullets: result.bullets,
                                     url: url)
            }
        }

        // Fallback to Gemini
        if let gemini = geminiClient {
            if let result = try? await gemini(url, cleanText, language) {
                return SummaryResult(title: result.title.isEmpty ? title : result.title,
                                     bullets: result.bullets,
                                     url: url)
            }
        }

        throw CoordinatorError.allBackendsFailed
    }
}
```

- [ ] **Step 5: Run tests — verify PASS**

Expected: SummarizationCoordinatorTests — 3 tests pass.

- [ ] **Step 6: Commit**

```bash
git add ios/Shared/Summarization/SummarizationCoordinator.swift ios/Shared/Networking/URLFetcher.swift ios/NewsSummarizerTests/SummarizationCoordinatorTests.swift
git commit -m "feat: add SummarizationCoordinator with Mac-first, Gemini fallback"
```

---

## Task 10: Share Extension UI

**Files:**
- Create: `ios/ShareExtension/Views/LoadingView.swift`
- Create: `ios/ShareExtension/Views/SummaryView.swift`
- Create: `ios/ShareExtension/ShareRootView.swift`
- Modify: `ios/ShareExtension/ShareViewController.swift`

- [ ] **Step 1: Create LoadingView**

```swift
// ios/ShareExtension/Views/LoadingView.swift
import SwiftUI

struct LoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.4)
            Text("正在摘要...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }
}
```

- [ ] **Step 2: Create SummaryView**

```swift
// ios/ShareExtension/Views/SummaryView.swift
import SwiftUI

struct SummaryView: View {
    let result: SummaryResult
    let onDismiss: () -> Void
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(result.title)
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                ForEach(result.bullets, id: \.self) { bullet in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .foregroundColor(.accentColor)
                        Text(bullet)
                            .font(.body)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            Divider()

            HStack {
                Link("原文連結", destination: result.url)
                    .font(.footnote)
                    .foregroundColor(.accentColor)
                Spacer()
                Button(copied ? "已複製" : "複製") {
                    UIPasteboard.general.string = formatForCopy()
                    copied = true
                }
                .font(.footnote)
                .buttonStyle(.bordered)

                Button("關閉") { onDismiss() }
                    .font(.footnote)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
    }

    private func formatForCopy() -> String {
        let bulletLines = result.bullets.map { "• \($0)" }.joined(separator: "\n")
        return "\(result.title)\n\n\(bulletLines)\n\n\(result.url.absoluteString)"
    }
}
```

- [ ] **Step 3: Create ShareRootView**

```swift
// ios/ShareExtension/ShareRootView.swift
import SwiftUI

enum ShareState {
    case loading
    case success(SummaryResult)
    case error(String)
    case unconfigured
}

struct ShareRootView: View {
    let extensionContext: NSExtensionContext?
    @State private var state: ShareState = .loading

    var body: some View {
        Group {
            switch state {
            case .loading:
                LoadingView()
            case .success(let result):
                ScrollView {
                    SummaryView(result: result, onDismiss: dismiss)
                }
            case .error(let message):
                ErrorView(message: message, onRetry: startSummarization, onDismiss: dismiss)
            case .unconfigured:
                UnconfiguredView(onDismiss: dismiss)
            }
        }
        .frame(minHeight: 200)
        .task { startSummarization() }
    }

    private func startSummarization() {
        Task {
            state = .loading
            let settings = SettingsStore()
            guard settings.isConfigured else {
                state = .unconfigured
                return
            }
            do {
                let url = try await extractURL()
                let coordinator = SummarizationCoordinator.make(settings: settings)
                let result = try await coordinator.summarize(url: url, language: settings.language)
                state = .success(result)
            } catch {
                state = .error(error.localizedDescription)
            }
        }
    }

    private func extractURL() async throws -> URL {
        guard let context = extensionContext else { throw CoordinatorError.noURL }
        for item in (context.inputItems as? [NSExtensionItem]) ?? [] {
            for provider in item.attachments ?? [] {
                if provider.hasItemConformingToTypeIdentifier("public.url") {
                    let loaded = try await provider.loadItem(forTypeIdentifier: "public.url", options: nil)
                    if let url = loaded as? URL { return url }
                }
                if provider.hasItemConformingToTypeIdentifier("public.plain-text") {
                    let loaded = try await provider.loadItem(forTypeIdentifier: "public.plain-text", options: nil)
                    if let text = loaded as? String,
                       let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)) {
                        return url
                    }
                }
            }
        }
        throw CoordinatorError.noURL
    }

    private func dismiss() {
        extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }
}

// MARK: - Supporting views

private struct ErrorView: View {
    let message: String
    let onRetry: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.orange)
            Text("摘要失敗")
                .font(.headline)
            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            HStack {
                Button("重試", action: onRetry).buttonStyle(.bordered)
                Button("關閉", action: onDismiss).buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
    }
}

private struct UnconfiguredView: View {
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "gearshape")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text("請先開啟 NewsSummarizer App 進行設定")
                .font(.body)
                .multilineTextAlignment(.center)
            Button("關閉", action: onDismiss).buttonStyle(.borderedProminent)
        }
        .padding(24)
    }
}
```

- [ ] **Step 4: Create ShareViewController**

```swift
// ios/ShareExtension/ShareViewController.swift
import UIKit
import SwiftUI

class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        let rootView = ShareRootView(extensionContext: extensionContext)
        let host = UIHostingController(rootView: rootView)
        addChild(host)
        view.addSubview(host.view)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        host.didMove(toParent: self)
    }
}
```

- [ ] **Step 5: Build in Xcode — verify compiles**

Product → Build (⌘B). Expected: build succeeds with 0 errors.

- [ ] **Step 6: Commit**

```bash
git add ios/ShareExtension/
git commit -m "feat: add Share Extension UI with SwiftUI"
```

---

## Task 11: Main App Settings UI

**Files:**
- Modify: `ios/NewsSummarizer/NewsSummarizerApp.swift` (already has SettingsView root)
- Create: `ios/NewsSummarizer/SettingsView.swift`

- [ ] **Step 1: Implement SettingsView**

```swift
// ios/NewsSummarizer/SettingsView.swift
import SwiftUI

struct SettingsView: View {
    @StateObject private var settings = SettingsStore()
    @State private var connectionStatus: String? = nil
    @State private var testing = false

    var body: some View {
        NavigationView {
            Form {
                Section("語言 / Language") {
                    Picker("語言", selection: $settings.language) {
                        ForEach(Language.allCases, id: \.self) { lang in
                            Text(lang.displayName).tag(lang)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Mac 伺服器 (Tailscale)") {
                    TextField("Tailscale IP (e.g. 100.x.x.x)", text: $settings.macTailscaleIP)
                        .keyboardType(.numbersAndPunctuation)
                        .autocorrectionDisabled()
                    SecureField("共用密鑰 (Shared Secret)", text: secureBinding(\.sharedSecret))
                    Button(testing ? "測試中..." : "測試連線") { testConnection() }
                        .disabled(settings.macTailscaleIP.isEmpty || testing)
                    if let status = connectionStatus {
                        Text(status)
                            .font(.caption)
                            .foregroundColor(status.contains("成功") ? .green : .red)
                    }
                }

                Section("備援 AI (Gemini Flash)") {
                    SecureField("Gemini API Key", text: secureBinding(\.geminiAPIKey))
                    Link("取得免費 API Key", destination: URL(string: "https://aistudio.google.com/app/apikey")!)
                        .font(.footnote)
                }

                Section("說明") {
                    Text("1. 安裝 Tailscale 在 Mac 和 iPhone")
                    Text("2. 執行 Mac 伺服器：cd mac-server && python3 server.py")
                    Text("3. 填入 Mac 的 Tailscale IP（執行 tailscale ip -4）")
                    Text("4. 在 LINE 或瀏覽器分享連結時選擇此 App")
                }
            }
            .navigationTitle("NewsSummarizer")
        }
    }

    private func secureBinding(_ kp: ReferenceWritableKeyPath<SettingsStore, String>) -> Binding<String> {
        Binding(get: { settings[keyPath: kp] }, set: { settings[keyPath: kp] = $0 })
    }

    private func testConnection() {
        guard let url = settings.macServerURL else { return }
        testing = true
        connectionStatus = nil
        Task {
            let client = MacClient(serverURL: url, sharedSecret: settings.sharedSecret)
            do {
                _ = try await client.summarize(
                    url: URL(string: "https://example.com")!,
                    cleanText: "ping",
                    language: settings.language
                )
                connectionStatus = "✓ 連線成功"
            } catch {
                connectionStatus = "✗ 連線失敗: \(error.localizedDescription)"
            }
            testing = false
        }
    }
}
```

- [ ] **Step 2: Build — verify compiles**

Product → Build (⌘B). Expected: 0 errors.

- [ ] **Step 3: Commit**

```bash
git add ios/NewsSummarizer/SettingsView.swift
git commit -m "feat: add Settings UI for Mac server and Gemini configuration"
```

---

## Task 12: Mac Server

**Files:**
- Create: `mac-server/server.py`
- Create: `mac-server/config.example.json`
- Create: `mac-server/setup.sh`

- [ ] **Step 1: Create server.py**

```python
#!/usr/bin/env python3
# mac-server/server.py
import json
import subprocess
import os
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer

CONFIG_PATH = os.path.expanduser("~/.config/newssummarizer/config.json")
PORT = 8765


def load_secret() -> str:
    try:
        with open(CONFIG_PATH) as f:
            return json.load(f).get("secret", "")
    except FileNotFoundError:
        print(f"Config not found at {CONFIG_PATH}. Run setup.sh first.", file=sys.stderr)
        sys.exit(1)


SECRET = load_secret()


class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        if self.path != "/summarize":
            self._respond(404, {"error": "not_found"})
            return

        if self.headers.get("X-Secret") != SECRET:
            self._respond(401, {"error": "unauthorized"})
            return

        length = int(self.headers.get("Content-Length", 0))
        body = json.loads(self.rfile.read(length))

        clean_text = body.get("cleanText", "")[:4000]
        language = body.get("language", "zh-TW")
        url = body.get("url", "")

        prompt = (
            f"Summarize the following article in {language}.\n"
            "Return ONLY valid JSON with no markdown, no code fences:\n"
            '{"title": "article title", "bullets": ["point 1", "point 2", "point 3"]}\n\n'
            f"Article:\n{clean_text}"
        )

        try:
            result = subprocess.run(
                ["claude", "-p", prompt],
                capture_output=True, text=True, timeout=30
            )
            raw = result.stdout.strip()
            # Strip markdown code fences if claude wraps in ```json ... ```
            if raw.startswith("```"):
                raw = "\n".join(raw.split("\n")[1:-1])
            summary = json.loads(raw)
            summary["url"] = url
            self._respond(200, summary)
        except subprocess.TimeoutExpired:
            self._respond(504, {"error": "claude_timeout"})
        except json.JSONDecodeError:
            self._respond(500, {"error": "parse_failed", "raw": result.stdout[:200]})

    def _respond(self, status: int, body: dict):
        payload = json.dumps(body).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", len(payload))
        self.end_headers()
        self.wfile.write(payload)

    def log_message(self, format, *args):
        pass  # suppress per-request logs


if __name__ == "__main__":
    server = HTTPServer(("0.0.0.0", PORT), Handler)
    print(f"NewsSummarizer server listening on port {PORT}", flush=True)
    server.serve_forever()
```

- [ ] **Step 2: Create config.example.json**

```json
{
  "secret": "REPLACE_WITH_YOUR_SECRET_TOKEN"
}
```

- [ ] **Step 3: Create setup.sh**

```bash
#!/usr/bin/env bash
# mac-server/setup.sh
# Installs Mac server as a LaunchAgent (auto-starts on login)
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_DIR="$HOME/.config/newssummarizer"
PLIST_DIR="$HOME/Library/LaunchAgents"
PLIST_NAME="com.tslsun.newssummarizer.plist"

# Check dependencies
if ! command -v claude &>/dev/null; then
    echo "Error: 'claude' CLI not found. Install Claude Code first."
    exit 1
fi

# Create config if not exists
mkdir -p "$CONFIG_DIR"
if [ ! -f "$CONFIG_DIR/config.json" ]; then
    SECRET=$(openssl rand -hex 32)
    echo "{\"secret\": \"$SECRET\"}" > "$CONFIG_DIR/config.json"
    echo "Generated secret: $SECRET"
    echo "Save this in your iOS app Settings > Shared Secret"
else
    echo "Config already exists at $CONFIG_DIR/config.json"
    SECRET=$(python3 -c "import json; print(json.load(open('$CONFIG_DIR/config.json'))['secret'])")
    echo "Existing secret: $SECRET"
fi

# Install LaunchAgent
mkdir -p "$PLIST_DIR"
cat > "$PLIST_DIR/$PLIST_NAME" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.tslsun.newssummarizer</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/bin/python3</string>
        <string>$SCRIPT_DIR/server.py</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/tmp/newssummarizer.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/newssummarizer.error.log</string>
</dict>
</plist>
EOF

launchctl unload "$PLIST_DIR/$PLIST_NAME" 2>/dev/null || true
launchctl load "$PLIST_DIR/$PLIST_NAME"

echo ""
echo "✓ Server installed and started"
echo "✓ Verify: curl -s http://localhost:8765/summarize || echo 'server running'"
echo ""
echo "Next steps:"
echo "  1. Open iOS app > Settings"
echo "  2. Enter Tailscale IP: $(tailscale ip -4 2>/dev/null || echo 'run: tailscale ip -4')"
echo "  3. Enter secret: $SECRET"
```

- [ ] **Step 4: Make setup.sh executable and run**

```bash
chmod +x mac-server/setup.sh
./mac-server/setup.sh
```

Expected output: "✓ Server installed and started" and a generated secret token.

- [ ] **Step 5: Verify server running**

```bash
curl -s -o /dev/null -w "%{http_code}" \
  -X POST http://localhost:8765/summarize \
  -H "X-Secret: wrong" \
  -H "Content-Type: application/json" \
  -d '{}'
```

Expected: `401`

- [ ] **Step 6: Commit**

```bash
git add mac-server/
git commit -m "feat: add Mac HTTP server with claude -p CLI and LaunchAgent setup"
```

---

## Task 13: Sideload and end-to-end test

- [ ] **Step 1: Regenerate project (if any source files added outside xcodegen)**

```bash
cd ios && xcodegen generate
```

- [ ] **Step 2: Build and sideload in Xcode**

1. Connect iPhone via USB
2. Select your iPhone as build target
3. Product → Run (⌘R) — installs main app
4. Verify Settings screen appears, enter your config values

- [ ] **Step 3: Test Mac server reachability**

In iOS Settings screen, tap "測試連線". Expected: "✓ 連線成功"

- [ ] **Step 4: End-to-end test — share a news URL from LINE**

1. Open LINE, tap a news link
2. Tap Share → select NewsSummarizer
3. Expected flow:
   - Loading spinner appears
   - ~5 seconds
   - Structured summary appears: title + bullets + original link

- [ ] **Step 5: Test fallback — stop Mac server and share again**

```bash
launchctl unload ~/Library/LaunchAgents/com.tslsun.newssummarizer.plist
```

Expected: extension falls back to Gemini and still shows summary.

- [ ] **Step 6: Re-enable Mac server**

```bash
launchctl load ~/Library/LaunchAgents/com.tslsun.newssummarizer.plist
```

- [ ] **Step 7: Final commit**

```bash
git add -A
git commit -m "feat: complete iOS news summarizer — share extension with Tailscale+Gemini fallback"
```

---

## Setup Summary (post-implementation steps for user)

1. **Mac:** `./mac-server/setup.sh` — installs server, generates secret
2. **Tailscale:** Install on Mac + iPhone, join same tailnet
3. **Mac IP:** `tailscale ip -4` → copy result
4. **iOS app:** Open NewsSummarizer → enter Tailscale IP + secret + Gemini key → test connection
5. **Use:** In LINE/Safari, tap Share → NewsSummarizer → summary appears inline
