import Foundation

/// Stores provider API keys in the device Keychain, keyed by configuration UUID string.
protocol CompanionCredentialsStoring: Sendable {
    func readKey(for configurationID: UUID) throws -> String?
    func writeKey(_ key: String, for configurationID: UUID) throws
    func deleteKey(for configurationID: UUID) throws
}

struct CompanionKeychainStore: CompanionCredentialsStoring {
    let secureStore: any ScriptureSecureStore

    init(secureStore: any ScriptureSecureStore = ScriptureKeychain(service: "com.personal.SophiaScriptura.companion-v1")) {
        self.secureStore = secureStore
    }

    func readKey(for configurationID: UUID) throws -> String? {
        guard let data = try secureStore.read(accountName(for: configurationID)) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func writeKey(_ key: String, for configurationID: UUID) throws {
        try secureStore.write(Data(key.utf8), name: accountName(for: configurationID))
    }

    func deleteKey(for configurationID: UUID) throws {
        try secureStore.remove(accountName(for: configurationID))
    }

    private func accountName(for configurationID: UUID) -> String {
        "provider-" + configurationID.uuidString
    }
}

/// In-memory credentials for unit tests.
final class InMemoryCompanionCredentialsStore: CompanionCredentialsStoring, @unchecked Sendable {
    private var keys: [UUID: String] = [:]
    private let lock = NSLock()

    func readKey(for configurationID: UUID) throws -> String? {
        lock.lock()
        defer { lock.unlock() }
        return keys[configurationID]
    }

    func writeKey(_ key: String, for configurationID: UUID) throws {
        lock.lock()
        defer { lock.unlock() }
        keys[configurationID] = key
    }

    func deleteKey(for configurationID: UUID) throws {
        lock.lock()
        defer { lock.unlock() }
        keys.removeValue(forKey: configurationID)
    }
}
