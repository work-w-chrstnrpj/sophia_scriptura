import Foundation

/// Sequential Hello AO chapter narration downloads for offline playback (SP-039 A3).
@MainActor
final class ScriptureNarrationDownloadQueue: ObservableObject {
    struct Snapshot: Equatable {
        var isRunning = false
        var completed = 0
        var total = 0
        var currentChapterID: String?
        var skippedUnavailable = 0
        var statusMessage: String?
    }

    @Published private(set) var snapshot = Snapshot()

    private let client = HelloAOChapterNarrationClient()
    private let mediaStore = ScriptureNarrationMediaStore()
    private var workTask: Task<Void, Never>?

    func cancel() {
        workTask?.cancel()
        workTask = nil
        if snapshot.isRunning {
            snapshot.isRunning = false
            snapshot.statusMessage = "Download cancelled."
            snapshot.currentChapterID = nil
        }
    }

    /// Downloads narration for every chapter in `chapterIDs` (e.g. `GEN.1`) for the given AO translation.
    func downloadAllChapters(
        aoTranslationID: String,
        narratorID: String,
        chapterIDs: [String]
    ) {
        guard !chapterIDs.isEmpty else {
            snapshot.statusMessage = "No chapters to download."
            return
        }
        guard !snapshot.isRunning else { return }

        workTask?.cancel()
        workTask = Task {
            snapshot = Snapshot(
                isRunning: true,
                completed: 0,
                total: chapterIDs.count,
                currentChapterID: nil,
                skippedUnavailable: 0,
                statusMessage: "Downloading narration… Keep Sophia open."
            )

            for chapterID in chapterIDs {
                if Task.isCancelled { break }
                guard let (bookID, chapter) = Self.parseChapterID(chapterID) else {
                    snapshot.completed += 1
                    continue
                }
                snapshot.currentChapterID = chapterID

                if await mediaStore.localAudioURL(
                    aoTranslationID: aoTranslationID,
                    narratorID: narratorID,
                    bookID: bookID,
                    chapter: chapter
                ) != nil {
                    snapshot.completed += 1
                    continue
                }

                do {
                    let remote = try await client.fetchChapterNarration(
                        translationID: aoTranslationID,
                        bookID: bookID,
                        chapter: chapter,
                        narratorID: narratorID
                    )
                    _ = try await mediaStore.ensureLocalPlaybackURL(
                        remotePackage: remote,
                        aoTranslationID: aoTranslationID,
                        narratorID: narratorID,
                        bookID: bookID,
                        chapter: chapter
                    )
                    snapshot.completed += 1
                } catch HelloAOChapterNarrationError.missingAudio {
                    snapshot.skippedUnavailable += 1
                    snapshot.completed += 1
                } catch is CancellationError {
                    break
                } catch {
                    snapshot.statusMessage = error.localizedDescription
                    break
                }
            }

            snapshot.isRunning = false
            snapshot.currentChapterID = nil
            if snapshot.statusMessage == nil || snapshot.statusMessage == "Downloading narration… Keep Sophia open." {
                if Task.isCancelled {
                    snapshot.statusMessage = "Download cancelled."
                } else if snapshot.completed >= snapshot.total {
                    let saved = snapshot.completed - snapshot.skippedUnavailable
                    if snapshot.skippedUnavailable > 0 {
                        snapshot.statusMessage = "Finished. \(saved) chapters saved; \(snapshot.skippedUnavailable) had no recording."
                    } else {
                        snapshot.statusMessage = "All \(saved) chapter recordings saved on this iPad."
                    }
                }
            }
            workTask = nil
        }
    }

    func downloadedCount(
        aoTranslationID: String,
        narratorID: String,
        chapterIDs: [String]
    ) async -> Int {
        var count = 0
        for chapterID in chapterIDs {
            guard let (bookID, chapter) = Self.parseChapterID(chapterID) else { continue }
            if await mediaStore.localAudioURL(
                aoTranslationID: aoTranslationID,
                narratorID: narratorID,
                bookID: bookID,
                chapter: chapter
            ) != nil {
                count += 1
            }
        }
        return count
    }

    private static func parseChapterID(_ id: String) -> (bookID: String, chapter: Int)? {
        let parts = id.split(separator: ".", maxSplits: 1)
        guard parts.count == 2, let chapter = Int(parts[1]) else { return nil }
        return (String(parts[0]), chapter)
    }
}
