import SwiftUI
import UniformTypeIdentifiers

struct SettingsStudyBackupSection: View {
    @Bindable var reader: ReaderSession
    var notes: NotesSession
    var annotations: AnnotationSession
    @ObservedObject var activity: ActivityStore
    @ObservedObject var collections: CollectionsStore
    @ObservedObject var companion: CompanionSession
    @Environment(\.appTheme) private var theme

    @State private var exporting = false
    @State private var importing = false
    @State private var confirmImport = false
    @State private var pendingImport: Data?
    @State private var archive = StudyBackupDocument(data: Data())
    @State private var notice: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Exports scripture annotations, notes, collections, companion conversations, and activity history. User music files and provider API keys stay on this device.")
                .font(.footnote)
                .foregroundStyle(Color(theme.palette.secondary))
            Button("Export all data") {
                Task {
                    do {
                        let data = try await StudyBackupService.export(
                            notes: notes,
                            annotations: annotations,
                            activity: activity,
                            collections: collections,
                            companion: companion
                        )
                        archive = StudyBackupDocument(data: data)
                        exporting = true
                    } catch {
                        notice = error.localizedDescription
                    }
                }
            }
            .font(.body.weight(.semibold))
            .foregroundStyle(Color(theme.palette.accent))
            .accessibilityIdentifier("settings.backup.export")

            Button("Import a backup…") { importing = true }
                .font(.body.weight(.semibold))
                .foregroundStyle(Color(theme.palette.accent))
                .accessibilityIdentifier("settings.backup.import")
        }
        .fileExporter(isPresented: $exporting, document: archive, contentType: .json, defaultFilename: "Sophia-Study-Backup") { result in
            if case .failure(let error) = result { notice = error.localizedDescription }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json], allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                guard url.startAccessingSecurityScopedResource() else { return }
                defer { url.stopAccessingSecurityScopedResource() }
                if let data = try? Data(contentsOf: url) {
                    pendingImport = data
                    confirmImport = true
                } else {
                    notice = "Could not read the backup file."
                }
            case .failure(let error):
                notice = error.localizedDescription
            }
        }
        .alert("Replace all study data?", isPresented: $confirmImport) {
            Button("Cancel", role: .cancel) { pendingImport = nil }
            Button("Import", role: .destructive) {
                guard let data = pendingImport else { return }
                Task {
                    do {
                        try await StudyBackupService.restore(
                            data,
                            notes: notes,
                            annotations: annotations,
                            activity: activity,
                            collections: collections,
                            companion: companion,
                            readerDocument: reader.document
                        )
                        notice = "Backup imported successfully."
                    } catch {
                        notice = error.localizedDescription
                    }
                    pendingImport = nil
                }
            }
        } message: {
            Text("Current notes, annotations, collections, companion data, and activity records will be replaced. Music and provider keys are not changed.")
        }
        .overlay(alignment: .top) {
            if let notice {
                TransientBannerNotice(message: notice)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onAppear {
                        Task {
                            try? await Task.sleep(for: .seconds(2.5))
                            withAnimation { self.notice = nil }
                        }
                    }
            }
        }
        .animation(.easeOut(duration: 0.2), value: notice != nil)
    }
}
