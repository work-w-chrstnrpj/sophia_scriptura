import Foundation
import Combine
import LocalAuthentication

/// Category grants are memory-only. Protection records bind to the original device credential.
@MainActor final class ItemProtectionSession: ObservableObject {
    enum Domain: String, CaseIterable, Hashable { case notes = "Notes", collections = "Collections" }
    struct Prompt: Identifiable { let id: UUID; let domains: Set<Domain>; let setup: Bool; var changePassword = false; var confirmRemoval = false }
    static let shared = ItemProtectionSession()
    static let idleInterval: TimeInterval = 600
    @Published private(set) var prompt: Prompt?
    @Published private(set) var unlocked: Set<Domain> = []
    @Published private(set) var obscured = false
    @Published private(set) var message: String?
    @Published private(set) var working = false
    private(set) var credential: ItemLockCredential?
    private var credentialReadFailed = false
    private let vault: any ItemLockCredentialVault
    private let now: () -> Date
    private var deadlines: [Domain: Date] = [:]
    private var continuation: CheckedContinuation<Void, Error>?
    private var timer: Timer?
    private let biometricsProvider: any ItemBiometricAuthenticating
    private var transitioning = false
    private var generation = UUID()
    /// Called while access still exists so native text/ink buffers are accepted before concealment.
    var willLock: ((Set<Domain>) -> Void)?

    init(vault: any ItemLockCredentialVault = ItemLockKeychain(), now: @escaping () -> Date = Date.init, startTimer: Bool = true, biometricsProvider: (any ItemBiometricAuthenticating)? = nil) {
        self.biometricsProvider = biometricsProvider ?? SystemItemBiometrics()
        self.vault = vault; self.now = now
        do {
            let stored = try vault.read()
            guard stored == nil || stored!.isValid else { throw ItemLockError.credentialsUnavailable }
            credential = stored
        } catch { credentialReadFailed = true }
        if startTimer {
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.expire() }
            }
        }
    }
    func isLocked(_ binding: UUID?, in domain: Domain) -> Bool {
        guard let binding else { return false }
        return credentialReadFailed || binding != credential?.id || !unlocked.contains(domain) || (deadlines[domain] ?? .distantPast) <= now()
    }
    func activity(in domain: Domain) {
        guard !transitioning else { return }
        expire()
        guard !obscured, prompt == nil, unlocked.contains(domain) else { return }
        deadlines[domain] = now().addingTimeInterval(Self.idleInterval)
    }
    func expire() {
        guard !transitioning else { return }
        let expired = Set(unlocked.filter { (deadlines[$0] ?? .distantPast) <= now() })
        if !expired.isEmpty { lock(expired) }
    }
    func lock(_ domains: Set<Domain>) {
        generation = UUID()
        transitioning = true; willLock?(domains); transitioning = false
        // Invalidate even an authentication request for a category that was already locked.
        if let prompt, prompt.domains.isEmpty || !prompt.domains.isDisjoint(with: domains) { cancel() }
        unlocked.subtract(domains)
        for domain in domains { deadlines[domain] = nil }
    }
    func sceneActive(_ active: Bool, background: Bool = false) {
        if !active { transitioning = true; willLock?([]); transitioning = false }
        obscured = !active
        if background { cancel() }
        if active { expire() }
    }
    func require(_ bindings: [UUID?], in domain: Domain) throws {
        guard !bindings.contains(where: { isLocked($0, in: domain) }) else { throw ItemLockError.locked }
    }
    func authenticate(_ domains: Set<Domain>, setupIfNeeded: Bool = false) async throws {
        expire()
        guard prompt == nil else { throw ItemLockError.busy }
        guard !credentialReadFailed, credential != nil || setupIfNeeded else { throw ItemLockError.credentialsUnavailable }
        message = nil
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            prompt = Prompt(id: UUID(), domains: domains, setup: credential == nil)
        }
    }
    func changePassword() async throws {
        let expectedGeneration = generation
        try await authenticate([])
        guard generation == expectedGeneration else { throw ItemLockError.cancelled }
        guard prompt == nil, credential != nil else { throw ItemLockError.cancelled }
        message = nil
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            prompt = Prompt(id: UUID(), domains: Set(Domain.allCases), setup: true, changePassword: true)
        }
    }
    func authorize(_ records: [Domain: [UUID?]]) async throws {
        expire()
        let bindings = records.values.flatMap { $0 }.compactMap { $0 }
        guard bindings.allSatisfy({ $0 == credential?.id }), !credentialReadFailed || bindings.isEmpty else { throw ItemLockError.credentialsUnavailable }
        let needed = Set(records.compactMap { domain, ids in ids.contains(where: { isLocked($0, in: domain) }) ? domain : nil })
        if !needed.isEmpty { try await authenticate(needed) }
        for (domain, ids) in records { try require(ids, in: domain) }
    }
    func request(binding: UUID?, in domain: Domain) async throws {
        guard let binding else { return }
        guard binding == credential?.id, !credentialReadFailed else { throw ItemLockError.credentialsUnavailable }
        if isLocked(binding, in: domain) { try await authenticate([domain]) }
        try require([binding], in: domain)
        activity(in: domain)
    }

    /// Removing a lock always asks again, even when that category is already unlocked.
    func confirmRemoval(binding: UUID?, in domain: Domain) async throws {
        expire()
        guard let binding, binding == credential?.id, !credentialReadFailed else { throw ItemLockError.credentialsUnavailable }
        guard prompt == nil else { throw ItemLockError.busy }
        message = nil
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            prompt = Prompt(id: UUID(), domains: [domain], setup: false, confirmRemoval: true)
        }
        try require([binding], in: domain)
    }
    func password(_ password: String, confirmation: String) async {
        guard let request = prompt, !working else { return }
        if request.setup, password != confirmation { message = "Passwords do not match."; return }
        if !request.setup, let retry = credential?.retryAfter, retry > now() { message = ItemLockError.throttled.localizedDescription; return }
        working = true
        let original = credential
        do {
            let result = try await Task.detached(priority: .userInitiated) {
                if let original, !request.setup {
                    guard try original.verifies(password) else { throw ItemLockError.wrongPassword }
                    return original
                }
                let fresh = try ItemLockCredential.make(password: password)
                if request.changePassword, let original { return ItemLockCredential(id: original.id, salt: fresh.salt, verifier: fresh.verifier, rounds: fresh.rounds) }
                return fresh
            }.value
            guard prompt?.id == request.id else { working = false; return }
            var reset = result; reset.failures = 0; reset.retryAfter = nil
            try vault.write(reset); credential = reset
            finish(request)
            if request.changePassword { lock(Set(Domain.allCases)) }
        } catch {
            guard prompt?.id == request.id else { working = false; return }
            if case ItemLockError.wrongPassword = error, var record = credential {
                record.failures = min(record.failures + 1, 10_000)
                if record.failures >= 5 { record.retryAfter = now().addingTimeInterval(30 * pow(2, Double(min(record.failures - 5, 5)))) }
                do { try vault.write(record); credential = record } catch { credentialReadFailed = true }
            }
            message = error.localizedDescription
        }
        working = false
    }
    func biometrics() async {
        guard let request = prompt, !request.setup, !working, credential != nil, !credentialReadFailed else { return }
        working = true
        do {
            let success = try await biometricsProvider.authenticate()
            guard prompt?.id == request.id else { working = false; return }
            if success { finish(request) }
        } catch { if prompt?.id == request.id { message = "Use your password or try biometrics again." } }
        working = false
    }
    private func finish(_ request: Prompt) {
        guard prompt?.id == request.id else { return }
        if !request.changePassword {
            unlocked.formUnion(request.domains)
            for domain in request.domains { deadlines[domain] = now().addingTimeInterval(Self.idleInterval) }
        }
        prompt = nil; message = nil
        let waiting = continuation; continuation = nil; waiting?.resume()
    }
    func cancel() {
        generation = UUID()
        biometricsProvider.cancel()
        prompt = nil; message = nil
        let waiting = continuation; continuation = nil; waiting?.resume(throwing: ItemLockError.cancelled)
    }

    /// Item removal invalidates an in-flight request for that category only.
    func cancel(affecting domains: Set<Domain>) {
        guard let prompt, !prompt.domains.isDisjoint(with: domains) else { return }
        cancel()
    }
}

struct ItemProtectionControlState: Equatable {
    var summary: String
    var explanation: String?
    var lockAllEnabled: Bool
    var unlockAllEnabled: Bool
    var notesEnabled: Bool
    var collectionsEnabled: Bool
    var notesStatus: String
    var collectionsStatus: String

    func status(_ domain: ItemProtectionSession.Domain) -> String {
        switch domain {
        case .notes: notesStatus
        case .collections: collectionsStatus
        }
    }

    static func make(notesProtected: Bool, collectionsProtected: Bool, unlocked: Set<ItemProtectionSession.Domain>) -> Self {
        let notesOpen = notesProtected && unlocked.contains(.notes)
        let collectionsOpen = collectionsProtected && unlocked.contains(.collections)
        let relevant = (notesProtected ? 1 : 0) + (collectionsProtected ? 1 : 0)
        let open = (notesOpen ? 1 : 0) + (collectionsOpen ? 1 : 0)
        let summary: String
        if relevant == 0 { summary = "No protected items" }
        else if open == 0 { summary = "Fully locked" }
        else if open == relevant { summary = "Fully unlocked" }
        else { summary = "Partially unlocked" }
        let explanation = relevant == 0
            ? "No notes or collections are protected yet. Protect an item from its menu. These actions do not add or remove protection."
            : nil
        func label(protected: Bool, open: Bool, empty: String) -> String {
            guard protected else { return empty }
            return open ? "Unlocked" : "Locked"
        }
        return Self(
            summary: summary,
            explanation: explanation,
            lockAllEnabled: open > 0,
            unlockAllEnabled: open < relevant,
            notesEnabled: notesProtected,
            collectionsEnabled: collectionsProtected,
            notesStatus: label(protected: notesProtected, open: notesOpen, empty: "No protected notes"),
            collectionsStatus: label(protected: collectionsProtected, open: collectionsOpen, empty: "No protected collections")
        )
    }
}

@MainActor protocol ItemBiometricAuthenticating {
    func authenticate() async throws -> Bool
    func cancel()
}
@MainActor final class SystemItemBiometrics: ItemBiometricAuthenticating {
    private var context: LAContext?
    func authenticate() async throws -> Bool {
        let auth = LAContext(); context = auth; auth.localizedFallbackTitle = ""
        var error: NSError?
        guard auth.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else { throw ItemLockError.credentialsUnavailable }
        defer { context = nil }
        return try await auth.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Unlock protected Sophia items")
    }
    func cancel() { context?.invalidate(); context = nil }
}
