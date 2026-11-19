import Foundation
import Security

/// Keychain 读写：Web Key 等机密只存这里，不落明文、不进 SwiftData。
enum KeychainStore {
    private static let service = "app.magpie.remote.webkey"
    private static let legacyPrefix = "magpie_vault_"

    static func save(_ value: String, for account: String) -> Bool {
        let query = query(for: account)
        let data = Data(value.utf8)
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var attributes = query
            attributes[kSecValueData as String] = data
            attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            guard SecItemAdd(attributes as CFDictionary, nil) == errSecSuccess else { return false }
        } else if status != errSecSuccess {
            return false
        }
        UserDefaults.standard.removeObject(forKey: legacyPrefix + account)
        return true
    }

    static func read(for account: String) -> String? {
        var attributes = query(for: account)
        attributes[kSecReturnData as String] = true
        attributes[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(attributes as CFDictionary, &item)
        let defaults = UserDefaults.standard
        let legacyKey = legacyPrefix + account
        if status == errSecSuccess, let data = item as? Data, let value = String(data: data, encoding: .utf8), !value.isEmpty {
            defaults.removeObject(forKey: legacyKey)
            return value
        }
        // 旧版在偏好设置留有明文副本；确认写入 Keychain 后才清除。
        guard status == errSecItemNotFound,
              let legacyValue = defaults.string(forKey: legacyKey), !legacyValue.isEmpty,
              save(legacyValue, for: account) else { return nil }
        return legacyValue
    }

    static func delete(for account: String) {
        SecItemDelete(query(for: account) as CFDictionary)
        UserDefaults.standard.removeObject(forKey: legacyPrefix + account)
    }

    private static func query(for account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}