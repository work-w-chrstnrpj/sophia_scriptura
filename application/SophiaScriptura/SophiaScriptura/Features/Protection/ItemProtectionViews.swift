import SwiftUI
import UIKit

/// Hold-menu actions for one note or collection.
enum ItemProtectionMenu: Equatable {
    case protect
    case unlock
    case lockAndRemove

    static func actions(protectionID: UUID?, locked: Bool) -> Self {
        if protectionID == nil { return .protect }
        return locked ? .unlock : .lockAndRemove
    }
}

@ViewBuilder
func ItemProtectionContextActions(
    noun: String,
    protectionID: UUID?,
    locked: Bool,
    protect: @escaping () -> Void,
    lock: @escaping () -> Void,
    unlock: @escaping () -> Void,
    remove: @escaping () -> Void
) -> some View {
    switch ItemProtectionMenu.actions(protectionID: protectionID, locked: locked) {
    case .protect:
        Button("Protect \(noun)", systemImage: "lock", action: protect)
            .accessibilityIdentifier("protection.\(noun.lowercased()).protect")
    case .unlock:
        Button("Unlock \(noun)", systemImage: "lock.open", action: unlock)
            .accessibilityIdentifier("protection.\(noun.lowercased()).unlock")
    case .lockAndRemove:
        Button("Lock \(noun)", systemImage: "lock", action: lock)
            .accessibilityIdentifier("protection.\(noun.lowercased()).lock")
        Button("Remove \(noun) Protection", systemImage: "lock.slash", action: remove)
            .accessibilityIdentifier("protection.\(noun.lowercased()).remove")
    }
}

struct ItemUnlockView: View {
    @ObservedObject var protection: ItemProtectionSession
    let prompt: ItemProtectionSession.Prompt
    @State private var password = ""
    @State private var confirmation = ""
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(headline)
                        .font(.headline)
                    Text("One password backs up biometrics. Notes and Collections unlock independently. Keep this password safe; there is no password reset that bypasses protection.")
                        .font(.footnote)
                    SecureField("Lock password", text: $password)
                        .textContentType(prompt.setup ? .newPassword : .password)
                        .accessibilityIdentifier("protection.password")
                    if prompt.setup {
                        SecureField("Confirm password", text: $confirmation)
                            .textContentType(.newPassword)
                            .accessibilityIdentifier("protection.confirmPassword")
                    }
                    Button(prompt.changePassword ? "Change Password" : prompt.confirmRemoval ? "Remove with Password" : prompt.setup ? "Set Password" : "Unlock with Password") {
                        let submitted = password; let confirmed = confirmation
                        password = ""; confirmation = ""
                        Task { await protection.password(submitted, confirmation: confirmed) }
                    }
                    .disabled(protection.working)
                    .accessibilityIdentifier("protection.submit")
                    if !prompt.setup {
                        Button("Use Touch ID / Face ID") { Task { await protection.biometrics() } }
                            .disabled(protection.working)
                            .accessibilityIdentifier("protection.biometrics")
                    }
                    if let message = protection.message { Text(message).foregroundStyle(.red) }
                    if protection.working { ProgressView() }
                }
            }
            .navigationTitle(prompt.changePassword ? "Change Lock Password" : prompt.confirmRemoval ? "Remove Protection" : prompt.setup ? "Set Up Protection" : "Unlock")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { protection.cancel() } } }
            .interactiveDismissDisabled()
            .task { if !prompt.setup { await protection.biometrics() } }
        }
    }

    private var headline: String {
        if prompt.changePassword { return "Choose a new lock password" }
        if prompt.confirmRemoval { return "Confirm with Touch ID, Face ID, or your lock password" }
        if prompt.setup { return "Create your Sophia lock password" }
        if prompt.domains.isEmpty { return "Confirm your current lock password" }
        return "Unlock \(prompt.domains.map(\.rawValue).sorted().joined(separator: " & "))"
    }
}

struct ProtectionControls: View {
    @Environment(\.appTheme) private var theme
    @ObservedObject var protection: ItemProtectionSession = .shared
    var domains: Set<ItemProtectionSession.Domain>
    var settings = false
    var available = true
    @State private var message: String?
    private var allUnlocked: Bool { domains.isSubset(of: protection.unlocked) }
    var body: some View {
        HStack {
            control
        }
        .alert("Protection", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) { Button("OK") { message = nil } } message: { Text(message ?? "") }
    }

    @ViewBuilder
    private var control: some View {
        let button = Button {
            guard available else { return }
            protection.expire()
            if allUnlocked { protection.lock(domains) }
            else { Task { do { try await protection.authenticate(domains) } catch { if case ItemLockError.cancelled = error {} else { message = error.localizedDescription } } } }
        } label: {
            Label(available ? (allUnlocked ? "Lock protected items" : "Unlock protected items") : "No protected items", systemImage: allUnlocked ? "lock.open" : "lock")
        }
        .disabled(!available)
        .accessibilityIdentifier(domains.count == 2 ? "protection.all.toggle" : "protection.\(settings ? "settings." : "")\(domains.first!.rawValue.lowercased()).toggle")
        if settings {
            button
                .buttonStyle(.plain)
                .font(.body.weight(.semibold))
                .foregroundStyle(Color(available ? theme.palette.accent : theme.palette.secondary))
        } else {
            button
        }
    }
}

struct ProtectionSettingsSection: View {
    var notesProtected: Bool
    var collectionsProtected: Bool
    @Environment(\.appTheme) private var theme
    @ObservedObject var protection: ItemProtectionSession = .shared
    @State private var message: String?
    private var controls: ItemProtectionControlState {
        .make(notesProtected: notesProtected, collectionsProtected: collectionsProtected, unlocked: protection.unlocked)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(controls.summary)
                .font(.body.weight(.semibold))
                .foregroundStyle(Color(theme.palette.ink))
                .accessibilityIdentifier("protection.state")
            Text("Only items with protection set up are affected. Titles remain visible; content and settings stay private while locked. These are app access locks; storage and exported backups are not encrypted.")
                .font(.footnote)
                .foregroundStyle(Color(theme.palette.secondary))
            if let explanation = controls.explanation {
                Text(explanation)
                    .font(.footnote)
                    .foregroundStyle(Color(theme.palette.secondary))
            }
            ForEach(ItemProtectionSession.Domain.allCases, id: \.self) { domain in
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(domain.rawValue)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Color(theme.palette.ink))
                        Text(controls.status(domain))
                            .font(.footnote)
                            .foregroundStyle(Color(theme.palette.secondary))
                    }
                    Spacer(minLength: 8)
                    ProtectionControls(domains: [domain], settings: true, available: domain == .notes ? controls.notesEnabled : controls.collectionsEnabled)
                }
                .padding(.vertical, 4)
            }
            settingsAction("Lock All Notes & Collections", identifier: "protection.all.lock", enabled: controls.lockAllEnabled) {
                protection.lock(Set(ItemProtectionSession.Domain.allCases))
            }
            settingsAction("Unlock All Notes & Collections", identifier: "protection.all.unlock", enabled: controls.unlockAllEnabled) {
                guard controls.unlockAllEnabled else { return }
                Task { do { try await protection.authenticate(Set(ItemProtectionSession.Domain.allCases)) } catch { if case ItemLockError.cancelled = error {} else { message = error.localizedDescription } } }
            }
            if protection.credential != nil {
                settingsAction("Change lock password", identifier: "protection.password.change", enabled: true) {
                    Task { do { try await protection.changePassword() } catch { if case ItemLockError.cancelled = error {} else { message = error.localizedDescription } } }
                }
            }
            Text("Access locks after 10 minutes without activity in that category and at the next app launch. Lock passwords stay on this device; protected backups must be restored on the original device. Archive and delete remain available while locked.")
                .font(.footnote)
                .foregroundStyle(Color(theme.palette.secondary))
        }
        .onAppear { protection.expire() }
        .alert("Protection", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) { Button("OK") { message = nil } } message: { Text(message ?? "") }
    }

    private func settingsAction(_ title: String, identifier: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .font(.body.weight(.semibold))
            .foregroundStyle(Color(enabled ? theme.palette.accent : theme.palette.secondary))
            .frame(maxWidth: .infinity, alignment: .leading)
            .disabled(!enabled)
            .accessibilityIdentifier(identifier)
    }
}

/// Observes actual input without taking gestures from text, scroll or Pencil surfaces.
struct ProtectionWindowObserver: UIViewRepresentable {
    @ObservedObject var protection: ItemProtectionSession
    var domain: ItemProtectionSession.Domain?
    func makeUIView(context: Context) -> Observer { Observer() }
    func updateUIView(_ view: Observer, context: Context) {
        view.activity = { if let domain { protection.activity(in: domain) } }
    }
    static func dismantleUIView(_ view: Observer, coordinator: ()) { view.detach() }
    final class Observer: UIView, UIGestureRecognizerDelegate {
        var activity: (() -> Void)?
        private weak var attachedWindow: UIWindow?
        private lazy var tracker = InputTracker(target: nil, action: nil)
        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard attachedWindow !== window else { return }
            detach(); attachedWindow = window
            tracker.input = { [weak self] in self?.activity?() }
            tracker.delegate = self; tracker.cancelsTouchesInView = false
            window?.addGestureRecognizer(tracker)
        }
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool { true }
        func detach() { attachedWindow?.removeGestureRecognizer(tracker); attachedWindow = nil }
    }
    final class InputTracker: UIGestureRecognizer {
        var input: (() -> Void)?
        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) { input?(); state = .began }
        override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) { input?(); state = .changed }
        override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) { state = .ended }
        override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) { state = .cancelled }
    }
}
