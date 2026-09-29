import SwiftUI

struct ScriptureVersionsView: View {
    @Bindable var session: ReaderSession
    @State private var key = ""
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    private var appearance: ScriptureAppearance { session.preferences.appearance }
    private var palette: ReaderPalette { session.preferences.palette(for:appearance,colorScheme:colorScheme) }
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label("Current: \(session.edition?.name ?? session.abbreviation)",systemImage:"checkmark.circle.fill")
                        .foregroundStyle(.tint)
                }
                Section("Bundled Bible") {
                    Button { Task { await session.selectEdition("web.engwebp"); dismiss() } } label: {
                        HStack { Text("World English Bible · WEB"); Spacer(); if session.edition?.id == "web.engwebp" { Image(systemName:"checkmark").accessibilityHidden(true) } }
                    }
                    Text("Always available offline. Public domain.").font(.caption)
                    Link("WEB publisher",destination:URL(string:"https://ebible.org/engwebp/")!)
                }
                Section("Licensed offline Bibles") {
                    ForEach(session.translations) { status in
                        VStack(alignment:.leading,spacing:8) {
                            Button {
                                Task { await session.selectEdition(status.translation.editionID); dismiss() }
                            } label: {
                                HStack { Text(status.translation.name + " · " + status.translation.abbreviation); Spacer(); if session.edition?.id == status.translation.editionID { Image(systemName:"checkmark").accessibilityHidden(true) } }
                            }.disabled(!status.isAvailable).accessibilityIdentifier("version.\(status.translation.abbreviation)")
                            if let expiry = status.expiresAt {
                                Text(status.isAvailable ? (OfflineContentPolicy.current.enforcesRefresh ? "Offline until \(expiry.formatted(date:.abbreviated,time:.shortened))" : "Development authorization · cached locally") : "Locked — sync to renew access")
                                    .font(.caption).foregroundStyle(.secondary)
                            } else { Text("Not downloaded").font(.caption).foregroundStyle(.secondary) }
                            Button(status.expiresAt == nil ? "Download \(status.translation.abbreviation)" : "Sync \(status.translation.abbreviation)") {
                                Task { await session.syncTranslation(status.id) }
                            }.disabled(session.syncing)
                        }.padding(.vertical,5)
                    }
                    if session.syncing { ProgressView(value:session.syncFraction) }
                    if let message = session.syncMessage { Text(message).font(.caption).accessibilityIdentifier("versions.status") }
                    Button("Sync all three now") { Task { await session.syncAllTranslations() } }.disabled(session.syncing)
                }
                Section("API.Bible connection") {
                    SecureField("API key",text:$key).textInputAutocapitalization(.never).autocorrectionDisabled()
                        .accessibilityIdentifier("versions.key")
                    Button("Save key on this device") {
                        let value = key; key = ""
                        Task { await session.configureProvider(key:value) }
                    }.disabled(key.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty || session.syncing)
                    Text(OfflineContentPolicy.current.enforcesRefresh ? "Syncing is manual only. Connect and press a Sync button at least every 30 days; expired translations lock until renewed. Keep Sophia open while downloading." : "Development authorization is active for NIV11, NLT and NKJV. Cached copies remain encrypted and local while you develop; production builds retain the normal refresh policy.").font(.caption)
                }
                Section("Attribution") {
                    Text(session.edition?.attribution ?? "")
                    Link("Scripture provided through API.Bible",destination:URL(string:"https://api.bible")!)
                    Link("NIV · Biblica",destination:URL(string:"https://www.biblica.com")!)
                    Link("NLT · Tyndale",destination:URL(string:"https://www.tyndale.com")!)
                    Link("NKJV · Thomas Nelson",destination:URL(string:"https://www.thomasnelsonbibles.com")!)
                }
            }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color(palette.paper))
                .foregroundStyle(Color(palette.ink))
                .tint(Color(palette.accent))
                .navigationTitle("Versions")
                .toolbar { Button("Done") { dismiss() } }
                .task { await session.refreshTranslations() }
        }.background(Color(palette.paper).ignoresSafeArea())
    }
}
