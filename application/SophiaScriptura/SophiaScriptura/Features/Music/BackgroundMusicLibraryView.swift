import SwiftUI
import UniformTypeIdentifiers

struct BackgroundMusicLibraryView: View {
    @ObservedObject var session: MusicSession
    @Environment(\.appTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @State private var importIntent: MusicImportIntent?
    @State private var renameTrack: MusicTrackDefinition?
    @State private var renameDraft = ""

    var body: some View {
        List {
            Section {
                Toggle("Loop all tracks", isOn: Binding(
                    get: { session.snapshot.loopAll },
                    set: { session.handle(.setLoopAll($0)) }
                ))
                .accessibilityIdentifier("music.loopAll")
            }
            Section {
                Button {
                    importIntent = .add
                } label: {
                    Label("Add music", systemImage: "plus.circle.fill")
                        .font(.body.weight(.semibold))
                }
                .accessibilityIdentifier("music.add")
                Text("Supported formats: MP3, M4A, AAC, WAV, AIFF, CAF—including files in Downloads from Safari. You are responsible for having rights to use them in the app.")
                    .font(.footnote)
                    .foregroundStyle(Color(theme.palette.secondary))
            }
            if !session.userTracks.isEmpty {
                Section("Your music") {
                    trackRows(session.userTracks, userLibrary: true)
                }
            }
            if !session.bundledTracks.isEmpty {
                Section("Bundled") {
                    trackRows(session.bundledTracks, userLibrary: false)
                }
            }
            if session.tracks.isEmpty {
                Section {
                    Text("No tracks yet. Use Add music to import audio from Files.")
                        .font(.footnote)
                        .foregroundStyle(Color(theme.palette.secondary))
                }
            }
            if session.showsNowActiveItem {
                Section {
                    Button("Stop background music", role: .destructive) {
                        session.handle(.clear)
                        dismiss()
                    }
                    .accessibilityIdentifier("music.clear")
                }
            }
            if let error = session.loadError {
                Section {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Background Music")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $importIntent) { intent in
            MusicFileImportPicker(
                onPick: { url in handleImport(url, intent: intent) },
                onCancel: { importIntent = nil }
            )
            .ignoresSafeArea()
        }
        .alert("Rename track", isPresented: Binding(
            get: { renameTrack != nil },
            set: { if !$0 { renameTrack = nil } }
        )) {
            TextField("Title", text: $renameDraft)
            Button("Cancel", role: .cancel) { renameTrack = nil }
            Button("Save") {
                if let track = renameTrack {
                    session.renameUserTrack(id: track.id, title: renameDraft)
                }
                renameTrack = nil
            }
        } message: {
            Text("Display name for this track in your library.")
        }
    }

    @ViewBuilder
    private func trackRows(_ tracks: [MusicTrackDefinition], userLibrary: Bool) -> some View {
        ForEach(tracks) { track in
            Button {
                session.handle(.selectTrack(track.id))
                dismiss()
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(track.title).font(.headline)
                        Text(track.composer).font(.caption).foregroundStyle(Color(theme.palette.secondary))
                    }
                    Spacer()
                    if session.snapshot.selectedTrackID == track.id {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color(theme.palette.accent))
                    }
                }
            }
            .accessibilityIdentifier("music.track.\(track.id)")
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                if userLibrary {
                    Button(role: .destructive) {
                        session.deleteUserTrack(id: track.id)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
            .contextMenu {
                if userLibrary {
                    Button("Rename", systemImage: "pencil") {
                        renameTrack = track
                        renameDraft = track.title
                    }
                    Button("Change audio file…", systemImage: "arrow.triangle.2.circlepath") {
                        importIntent = .replace(trackID: track.id)
                    }
                    Button("Delete", systemImage: "trash", role: .destructive) {
                        session.deleteUserTrack(id: track.id)
                    }
                }
            }
        }
    }

    private func handleImport(_ url: URL, intent: MusicImportIntent) {
        importIntent = nil
        guard MusicImportContentTypes.isSupportedFile(url) else {
            session.loadError = "That file type is not supported. Use MP3, M4A, AAC, WAV, AIFF, or CAF."
            return
        }
        switch intent {
        case .add:
            session.importUserTrack(from: url)
        case .replace(let trackID):
            session.replaceUserTrackFile(id: trackID, from: url)
        }
    }
}
