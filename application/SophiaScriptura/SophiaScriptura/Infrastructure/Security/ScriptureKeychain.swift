import Foundation
import Security
import CryptoKit

/// The production implementation keeps credentials and the encryption key in the
/// device-only Keychain. Tests inject an in-memory implementation of this boundary.
protocol ScriptureSecureStore: Sendable {
    func read(_ name: String) throws -> Data?
    func write(_ data: Data, name: String) throws
    func remove(_ name: String) throws
    func encryptionKey(create: Bool) throws -> SymmetricKey
}

/// Keys are never included in resources, preferences, diagnostics or iCloud Keychain.
struct ScriptureKeychain: ScriptureSecureStore {
    let service: String
    init(service: String = "com.personal.SophiaScriptura.licensed-v1") { self.service = service }
    func read(_ name: String) throws -> Data? {
        var query = base(name)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var value: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary,&value)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = value as? Data else { throw LicensedContentError.storage }
        return data
    }
    func write(_ data: Data, name: String) throws {
        let query = base(name)
        let result = SecItemUpdate(query as CFDictionary,[kSecValueData as String:data] as CFDictionary)
        if result == errSecItemNotFound {
            var insert = query
            insert[kSecValueData as String] = data
            insert[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            guard SecItemAdd(insert as CFDictionary,nil) == errSecSuccess else { throw LicensedContentError.storage }
        } else if result != errSecSuccess { throw LicensedContentError.storage }
    }
    func remove(_ name: String) throws {
        let status = SecItemDelete(base(name) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw LicensedContentError.storage }
    }
    func encryptionKey(create: Bool) throws -> SymmetricKey {
        if let data = try read("encryption"), data.count == 32 { return SymmetricKey(data:data) }
        guard create else { throw LicensedContentError.storage }
        let key = SymmetricKey(size:.bits256)
        try write(key.withUnsafeBytes { Data($0) },name:"encryption")
        return key
    }
    private func base(_ name: String) -> [String:Any] {
        [kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:service,
         kSecAttrAccount as String:name,kSecAttrSynchronizable as String:false]
    }
}
