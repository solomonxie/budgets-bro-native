import Foundation
import Security

/// Keychain wrapper for the AI API key and S3 credentials — never the
/// SQLite DB. `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` excludes these
/// items from iCloud/iTunes device backups. See
/// docs/DESIGN.md#secrets-vs-backups--never-mixed.
enum Keychain {
    private static let service = "com.solomonxie.budgetsbronative.secrets"

    static func set(_ value: String, for key: String) {
        let data = Data(value.utf8)
        var query = baseQuery(for: key)
        if SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess {
            SecItemUpdate(query as CFDictionary, [kSecValueData: data] as CFDictionary)
        } else {
            query[kSecValueData] = data
            query[kSecAttrAccessible] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            SecItemAdd(query as CFDictionary, nil)
        }
    }

    static func get(_ key: String) -> String? {
        var query = baseQuery(for: key)
        query[kSecReturnData] = true
        query[kSecMatchLimit] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func remove(_ key: String) {
        SecItemDelete(baseQuery(for: key) as CFDictionary)
    }

    private static func baseQuery(for key: String) -> [CFString: Any] {
        [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
        ]
    }
}

enum SecretKey {
    static let aiAPIKey = "ai_api_key"
    static let s3AccessKeyID = "s3_access_key_id"
    static let s3SecretAccessKey = "s3_secret_access_key"
    static let appPasscode = "app_lock_passcode"
}
