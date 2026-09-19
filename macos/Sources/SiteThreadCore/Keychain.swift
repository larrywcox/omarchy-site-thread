import Foundation
import Security

/// The macOS replacement for the Linux helper's `secret-tool` calls.
///
/// The API key lives in the login keychain as a generic password. It is never
/// written to the configuration file, never passed as a process argument, and
/// never logged.
public enum Keychain {
    public static let service = "com.larrywcox.site-thread"
    public static let account = "default"

    private static func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    public static func load() throws -> String? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else {
            throw SiteThreadError("The macOS keychain denied access to the stored API key")
        }
        guard let data = item as? Data, let key = String(data: data, encoding: .utf8) else {
            return nil
        }
        return key
    }

    public static func store(_ key: String) throws {
        guard let data = key.data(using: .utf8) else {
            throw SiteThreadError("The API key could not be encoded")
        }
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked,
            kSecAttrLabel as String: "UniFi SiteThread API key",
        ]

        let update = SecItemUpdate(baseQuery() as CFDictionary, attributes as CFDictionary)
        if update == errSecSuccess { return }
        if update != errSecItemNotFound {
            throw SiteThreadError("The macOS keychain rejected the API key")
        }

        var insert = baseQuery()
        for (name, value) in attributes { insert[name] = value }
        let status = SecItemAdd(insert as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw SiteThreadError("The macOS keychain rejected the API key")
        }
    }

    public static func clear() {
        SecItemDelete(baseQuery() as CFDictionary)
    }
}
