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
