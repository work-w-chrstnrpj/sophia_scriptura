import Foundation
import Security
import CommonCrypto

/// A device-bound verifier, never a plaintext password or a content encryption key.
struct ItemLockCredential: Codable, Equatable, Sendable {
    let id: UUID
    let salt: Data
    let verifier: Data
    let rounds: UInt32
    var failures = 0
    var retryAfter: Date? = nil

    var isValid: Bool {
        salt.count == 32 && verifier.count == 32 && rounds == 600_000 && (0...10_000).contains(failures)
            && (retryAfter == nil || retryAfter!.timeIntervalSince1970.isFinite)
    }

    static func make(password: String) throws -> Self {
        guard (10...256).contains(password.count) else { throw ItemLockError.passwordLength }
        var salt = Data(count: 32)
        let status = salt.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, $0.count, $0.baseAddress!) }
        guard status == errSecSuccess else { throw ItemLockError.credentialsUnavailable }
        let rounds: UInt32 = 600_000
        return Self(id: UUID(), salt: salt, verifier: try derive(password, salt: salt, rounds: rounds), rounds: rounds)
    }
    func verifies(_ password: String) throws -> Bool {
        guard (1...256).contains(password.count), salt.count == 32, verifier.count == 32, rounds == 600_000 else { return false }
        let candidate = try Self.derive(password, salt: salt, rounds: rounds)
        return zip(candidate, verifier).reduce(UInt8(0)) { $0 | ($1.0 ^ $1.1) } == 0
    }
    private static func derive(_ password: String, salt: Data, rounds: UInt32) throws -> Data {
        let bytes = Array(password.utf8)
        var result = Data(count: 32)
        let status = bytes.withUnsafeBytes { input in salt.withUnsafeBytes { saltBytes in result.withUnsafeMutableBytes { output in
            CCKeyDerivationPBKDF(CCPBKDFAlgorithm(kCCPBKDF2), input.baseAddress!.assumingMemoryBound(to: Int8.self), bytes.count,
                                saltBytes.baseAddress!.assumingMemoryBound(to: UInt8.self), salt.count,
                                CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256), rounds,
                                output.baseAddress!.assumingMemoryBound(to: UInt8.self), output.count)
        } } }
        guard status == kCCSuccess else { throw ItemLockError.credentialsUnavailable }
        return result
    }
}

protocol ItemLockCredentialVault {
    func read() throws -> ItemLockCredential?
    func write(_ credential: ItemLockCredential) throws
}
struct ItemLockKeychain: ItemLockCredentialVault {
    private var service: String {
        #if DEBUG
        if let raw = ProcessInfo.processInfo.environment["SP009_TEST_STORE"], let id = UUID(uuidString: raw) { return "org.sophia.item-protection.test." + id.uuidString }
        #endif
        return "org.sophia.item-protection"
    }
    private var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
         kSecAttrAccount as String: "app-password-v1"]
    }
    func read() throws -> ItemLockCredential? {
        var lookup = query
        lookup[kSecReturnData as String] = true
        lookup[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(lookup as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = item as? Data,
              let credential = try? JSONDecoder().decode(ItemLockCredential.self, from: data),
              credential.isValid else {
            throw ItemLockError.credentialsUnavailable
        }
        return credential
    }
    func write(_ credential: ItemLockCredential) throws {
        let attributes: [String: Any] = [kSecValueData as String: try JSONEncoder().encode(credential),
                                        kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly]
        var status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound { status = SecItemAdd(query.merging(attributes) { _, new in new } as CFDictionary, nil) }
        guard status == errSecSuccess else { throw ItemLockError.credentialsUnavailable }
    }
}

enum ItemLockError: Error, LocalizedError {
    case locked, cancelled, busy, credentialsUnavailable, passwordLength, wrongPassword, throttled
    var errorDescription: String? {
        switch self {
        case .locked: "Unlock the protected items before continuing."
        case .cancelled: "Unlock cancelled."
        case .busy: "Finish the current unlock request first."
        case .credentialsUnavailable: "The original lock credential is unavailable on this device. Protection cannot be reset or removed. Restore on the original device; archive or delete remains available."
        case .passwordLength: "Use a password between 10 and 256 characters."
        case .wrongPassword: "Incorrect password."
        case .throttled: "Too many attempts. Wait before trying again."
        }
    }
}
