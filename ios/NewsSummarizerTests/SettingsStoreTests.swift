import XCTest
@testable import NewsSummarizer

final class SettingsStoreTests: XCTestCase {
    var store: SettingsStore!
    var keychainService: String!

    override func setUp() {
        super.setUp()
        keychainService = "test-\(UUID().uuidString)"
        store = SettingsStore(
            defaults: UserDefaults(suiteName: "test-\(UUID().uuidString)")!,
            keychain: KeychainHelper(service: keychainService, accessGroup: nil)
        )
    }

    override func tearDown() {
        super.tearDown()
        let kc = KeychainHelper(service: keychainService, accessGroup: nil)
        kc.delete("sharedSecret")
        kc.delete("geminiAPIKey")
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
