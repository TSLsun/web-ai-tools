import Foundation
import Security

struct KeychainHelper {
    private let service: String
    private let accessGroup: String?

    init(service: String = "com.tslsun.newssummarizer",
         accessGroup: String? = "group.com.tslsun.newssummarizer") {
        self.service = service
        self.accessGroup = accessGroup
    }

    func set(_ value: String, for key: String) {
        guard let data = value.data(using: .utf8) else { return }
        var query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
        ]
        if let group = accessGroup { query[kSecAttrAccessGroup] = group }
        let attributes: [CFString: Any] = [kSecValueData: data]
        if SecItemUpdate(query as CFDictionary, attributes as CFDictionary) == errSecItemNotFound {
            var addQuery = query
            addQuery[kSecValueData] = data
            SecItemAdd(addQuery as CFDictionary, nil)
        }
    }

    func get(_ key: String) -> String {
        var query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
        ]
        if let group = accessGroup { query[kSecAttrAccessGroup] = group }
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else { return "" }
        return string
    }

    func delete(_ key: String) {
        var query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
        ]
        if let group = accessGroup { query[kSecAttrAccessGroup] = group }
        SecItemDelete(query as CFDictionary)
    }
}
