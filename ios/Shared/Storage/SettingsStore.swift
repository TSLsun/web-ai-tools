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
        set {
            keychain.set(newValue, for: "sharedSecret")
            objectWillChange.send()
        }
    }

    var geminiAPIKey: String {
        get { keychain.get("geminiAPIKey") }
        set {
            keychain.set(newValue, for: "geminiAPIKey")
            objectWillChange.send()
        }
    }

    var isConfigured: Bool {
        !macTailscaleIP.isEmpty || !geminiAPIKey.isEmpty
    }

    var macServerURL: URL? {
        guard !macTailscaleIP.isEmpty else { return nil }
        return URL(string: "http://\(macTailscaleIP):8765/summarize")
    }
}
