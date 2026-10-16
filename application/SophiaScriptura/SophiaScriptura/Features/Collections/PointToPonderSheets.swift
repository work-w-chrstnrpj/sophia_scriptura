import SwiftUI

struct PointToPonderCreatorSheet: View {
    @ObservedObject var store: CollectionsStore
    let collectionID: UUID
    @Environment(\.dismiss) private var dismiss
    @State private var question = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Question") {
                    TextField("What would you like to reflect on?", text: $question, axis: .vertical)
                        .lineLimit(3...8)
                        .accessibilityIdentifier("ponder.question")
                    Text("\(question.count)/200 characters").font(.caption).foregroundStyle(.secondary)
                }
                if let notice = store.notice { Text(notice).foregroundStyle(.secondary) }
            }
            .appSurface()
            .navigationTitle("New Point to Ponder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        if store.addPointToPonder(question: question, collectionID: collectionID) != nil { dismiss() }
                    }
                    .disabled(question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || question.count > 200)
                    .accessibilityIdentifier("ponder.create")
                }
            }
        }
    }
}

/// The host advances only after the preceding modal has finished dismissing.
struct PointToPonderFlow: ViewModifier {
    enum Step: String, Identifiable { case question, explore, note; var id: String { rawValue } }
    @ObservedObject var store: CollectionsStore
    @ObservedObject private var protection = ItemProtectionSession.shared
    let notes: NotesSession
    let point: PointToPonder?
    let collectionID: UUID
    let openNote: (UUID) -> Void
    let exploreQuestion: (String) -> UUID?
    let close: () -> Void
    @State private var step: Step?
    @State private var nextStep: Step?
    @State private var companionUnavailable = false

    func body(content: Content) -> some View {
        content
            .onChange(of: point?.id) { _, id in if id != nil { step = .question } }
            .sheet(item: $step, onDismiss: {
                if let nextStep { self.nextStep = nil; step = nextStep } else { close() }
            }) { current in
                if let point, store.pointsToPonder.contains(where: { $0.id == point.id && $0.trashedAt == nil }), !store.isLocked(collectionID) {
                    switch current {
                    case .question:
                        PointToPonderCard(question: point.question, explore: { advance(.explore) }, delete: {
                            store.trashPoint(point.id); step = nil
                        })
                    case .explore:
                        NavigationStack {
                            List {
                                Section { Text(point.question).font(.system(.title3, design: .serif)) }
                                Button("Send Question to Companion", systemImage: "bubble.left.and.bubble.right") {
                                    guard let id = exploreQuestion(point.question) else { companionUnavailable = true; return }
                                    for folderID in store.collectionIDs(containing: point.id).filter { !store.isLocked($0) } { store.addMembership(artifactID: id, collectionID: folderID) }
                                    step = nil
                                }
                                .accessibilityIdentifier("ponder.companion")
                                Button("Turn into a Note", systemImage: "note.text") { advance(.note) }
                                    .accessibilityIdentifier("ponder.note")
                                if companionUnavailable { Text("Configure a provider and model in Settings, and wait for any current response to finish before trying again.").foregroundStyle(.secondary) }
                                Section { Text("Your original question stays saved.").font(.footnote).foregroundStyle(.secondary) }
                            }
                            .appSurface()
                            .navigationTitle("Explore")
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Close") { step = nil } } }
                        }
                    case .note:
                        NoteCreatorSheet(notes: notes, initialTitle: point.question) { id in
                            store.link(notes: notes.snapshot.notes)
                            _ = store.setMemberships(artifactID: id, collectionIDs: Set(store.collectionIDs(containing: point.id).filter { !store.isLocked($0) }))
                            openNote(id)
                        }
                    }
                }
            }
            .onChange(of: protection.unlocked) { _, _ in
                if store.isLocked(collectionID) { nextStep = nil; step = nil; close() }
            }
    }

    private func advance(_ destination: Step) { nextStep = destination; step = nil }
}

private struct PointToPonderCard: View {
    let question: String
    let explore: () -> Void
    let delete: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var confirmingDelete = false
    @State private var contentHeight: CGFloat = 360

    var body: some View {
        fittedCard
            .alert("Move this question to Trash?", isPresented: $confirmingDelete) {
                Button("Delete", role: .destructive, action: delete)
                Button("Cancel", role: .cancel) {}
            } message: { Text("Restore it from Settings → Trash → Points to Ponder.") }
    }

    @ViewBuilder private var fittedCard: some View {
        if #available(iOS 18.0, *) {
            card.presentationSizing(.form.fitted(horizontal: false, vertical: true))
        } else {
            card.presentationDetents([.height(contentHeight)])
        }
    }

    private var card: some View {
        ViewThatFits(in: .vertical) {
            content
            ScrollView { content }
        }
        .appSurface()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("ponder.card")
    }

    private var content: some View {
        VStack(spacing: 24) {
            HStack(alignment: .center, spacing: 16) {
                Text("Point to Ponder").font(.headline)
                Spacer(minLength: 8)
                Button("Close", systemImage: "xmark") { dismiss() }
                    .labelStyle(.iconOnly)
                    .buttonStyle(CollectionSecondaryButtonStyle())
                    .accessibilityIdentifier("ponder.close")
            }
            Image(systemName: "questionmark.bubble").font(.largeTitle).foregroundStyle(.secondary)
            Text(question)
                .font(.system(.title, design: .serif))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
                .accessibilityIdentifier("ponder.card.question")
            VStack(spacing: 12) {
                Button("Explore", systemImage: "sparkle.magnifyingglass", action: explore)
                    .buttonStyle(CollectionProminentButtonStyle(fullWidth: true))
                    .accessibilityIdentifier("ponder.explore")
                Button("Delete", systemImage: "trash", role: .destructive) { confirmingDelete = true }
                    .buttonStyle(CollectionProminentButtonStyle(fullWidth: true, destructive: true))
                    .accessibilityIdentifier("ponder.delete")
            }
        }
        .padding(24)
        .frame(maxWidth: 620)
        .frame(maxWidth: .infinity)
        .background(GeometryReader { proxy in
            Color.clear.onAppear { contentHeight = proxy.size.height }
                .onChange(of: proxy.size.height) { _, height in contentHeight = height }
        })
    }
}
