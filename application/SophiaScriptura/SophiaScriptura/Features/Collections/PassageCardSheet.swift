import SwiftUI

struct PassageCardID: Identifiable { let id: UUID }


/// Centered card for one bookmark or gleaning. Gleanings add an insight with Edit, Save and Clear.
struct PassageCardSheet: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: CollectionsStore
    let passageID: UUID
    var seeChapter: (SavedPassage) -> Void

    var notes: NotesSession? = nil
    var openNote: (UUID) -> Void = { _ in }
    @State private var creatingNote = false

    @State private var editing = false
    @State private var draft = ""
    @State private var confirmingClear = false
    @FocusState private var insightFocused: Bool

    var body: some View {
        NavigationStack {
            Group {
                if let passage = store.passage(id: passageID) {
                    content(passage)
                } else {
                    ContentUnavailableView("Passage unavailable", systemImage: "bookmark.slash")
                }
            }
            .appSurface()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        commitIfEditing()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .sheet(isPresented: $creatingNote) {
            if let notes, let passage = store.passage(id: passageID) {
                NoteCreatorSheet(notes: notes, initialTitle: passage.gleaningNoteTitle,
                    initialContent: .companionResponse(text: passage.noteContent, anchor: nil)) { id in
                    store.link(notes: notes.snapshot.notes)
                    _ = store.setMemberships(artifactID: id, collectionIDs: Set(store.collectionIDs(containing: passageID).filter { !store.isLocked($0) }))
                    dismiss()
                    openNote(id)
                }
            }
        }
        .onDisappear(perform: commitIfEditing)
        .confirmationDialog("Clear this insight?", isPresented: $confirmingClear, titleVisibility: .visible) {
            Button("Clear Insight", role: .destructive) {
                draft = ""
                store.updateInsight(id: passageID, insight: "")
            }
        } message: {
            Text("The passage stays saved. Only your written insight is removed.")
        }
    }

    private func content(_ passage: SavedPassage) -> some View {
        let accent = store.accent(for: passage.id)
        let tint = accent.resolvedColor(in: theme)
        let isGleaning = passage.kind == .gleaning
        return ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .center, spacing: 14) {
                    CollectionItemGlyph(kind: isGleaning ? .gleaning : .bookmark, accent: accent, size: 48)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(isGleaning ? "GLEANING" : "BOOKMARK")
                            .font(.caption.weight(.semibold))
                            .tracking(1.4)
                            .foregroundStyle(tint)
                        Text(passage.referenceLabel)
                            .font(.system(.title2, design: .serif).weight(.semibold))
                            .foregroundStyle(Color(theme.palette.ink))
                            .accessibilityAddTraits(.isHeader)
                            .accessibilityIdentifier("collections.card.reference")
                    }
                }

                HStack(alignment: .top, spacing: 14) {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(tint)
                        .frame(width: 3)
                    Text(passage.passageText)
                        .font(.system(.title3, design: .serif))
                        .foregroundStyle(Color(theme.palette.ink))
                        .lineSpacing(5)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                        .accessibilityIdentifier("collections.card.passage")
                }
                .padding(.vertical, 4)

                if isGleaning {
                    insightSection(passage, accent: accent)
                }

                Button {
                    commitIfEditing()
                    seeChapter(passage)
                    dismiss()
                } label: {
                    Label("See the whole chapter", systemImage: "book.pages")
                }
                .buttonStyle(CollectionProminentButtonStyle(fullWidth: true))
                .accessibilityIdentifier("collections.seeChapter")

                if isGleaning, notes != nil {
                    Button("Turn into a Note", systemImage: "note.text") {
                        commitIfEditing()
                        creatingNote = true
                    }
                    .buttonStyle(CollectionSecondaryButtonStyle(fullWidth: true, transparent: true))
                    .accessibilityIdentifier("collections.gleaning.toNote")
                } else if !isGleaning {
                    Button("Turn into a Gleaning", systemImage: "laurel.leading") {
                        if store.turnBookmarkToGleaning(passageID) { editing = true; insightFocused = true }
                    }
                    .buttonStyle(CollectionSecondaryButtonStyle(fullWidth: true, transparent: true))
                    .accessibilityIdentifier("collections.bookmark.toGleaning")
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 8)
            .padding(.bottom, 28)
            .frame(maxWidth: 620, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .onAppear { draft = passage.insight }
        .onChange(of: draft) { _, value in
            if editing { store.updateInsight(id: passageID, insight: value.trimmingCharacters(in: .whitespacesAndNewlines)) }
        }
    }

    private func insightSection(_ passage: SavedPassage, accent: CollectionAccent) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                Text("Insight")
                    .font(.headline)
                    .foregroundStyle(Color(theme.palette.ink))
                Spacer()
                if editing {
                    Button("Clear") { draft = "" }
                        .buttonStyle(CollectionSecondaryButtonStyle(destructive: true))
                        .disabled(draft.isEmpty)
                        .accessibilityIdentifier("collections.insight.clear")
                    Button("Save") { save() }
                        .buttonStyle(CollectionSecondaryButtonStyle())
                        .accessibilityIdentifier("collections.insight.save")
                } else {
                    if !passage.insight.isEmpty {
                        Button("Clear") { confirmingClear = true }
                            .buttonStyle(CollectionSecondaryButtonStyle(destructive: true))
                            .accessibilityIdentifier("collections.insight.clear")
                    }
                    Button("Edit") {
                        draft = passage.insight
                        withAnimation(.easeOut(duration: 0.18)) { editing = true }
                        insightFocused = true
                    }
                    .buttonStyle(CollectionSecondaryButtonStyle())
                    .accessibilityIdentifier("collections.insight.edit")
                }
            }

            Group {
                if editing {
                    TextField("What did you glean from this passage?", text: $draft, axis: .vertical)
                        .lineLimit(4...12)
                        .focused($insightFocused)
                        .accessibilityIdentifier("collections.insight.field")
                } else if passage.insight.isEmpty {
                    Text("No insight yet. Choose Edit to write what you gleaned.")
                        .foregroundStyle(Color(theme.palette.secondary))
                } else {
                    Text(passage.insight)
                        .foregroundStyle(Color(theme.palette.ink))
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                        .accessibilityIdentifier("collections.insight.text")
                }
            }
            .font(.body)
            .lineSpacing(3)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(theme.palette.soft), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(editing ? accent.resolvedColor(in: theme).opacity(0.6) : Color(theme.palette.rule), lineWidth: 1)
            )
        }
    }

    private func save() {
        store.updateInsight(id: passageID, insight: draft.trimmingCharacters(in: .whitespacesAndNewlines))
        insightFocused = false
        withAnimation(.easeOut(duration: 0.18)) { editing = false }
    }

    private func commitIfEditing() {
        guard editing else { return }
        save()
    }
}
