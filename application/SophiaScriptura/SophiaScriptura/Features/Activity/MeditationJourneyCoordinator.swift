import Foundation
import SwiftUI

@MainActor final class MeditationJourneyCoordinator: ObservableObject {
    @Published private(set) var isActive = false
    @Published private(set) var pages: [MeditationJourneyPage] = []
    @Published var pageIndex = 0
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    func begin(
        launch: MeditationJourneyLaunch,
        books: [ScriptureBook],
        repositoryProvider: @escaping (String?) async throws -> any ScriptureContentRepository
    ) {
        guard !isLoading else { return }
        isActive = true
        isLoading = true
        errorMessage = nil
        pageIndex = 0
        pages = [.init(id: 0, kind: .intro)]
        Task {
            do {
                let repository = try await repositoryProvider(launch.editionID)
                let ranges = MeditationJourneyBuilder.ranges(for: launch)
                var resolved: [(PassageRange, [MeditationScriptureLine])] = []
                for range in ranges {
                    let lines = try await MeditationPassageResolver.displayLines(for: range, repository: repository)
                    guard !lines.isEmpty else { continue }
                    resolved.append((range, lines))
                }
                guard !resolved.isEmpty else { throw ScriptureError.passageUnmapped }
                pages = MeditationJourneyBuilder.pages(launch: launch, books: books, resolved: resolved)
                pageIndex = 0
            } catch {
                errorMessage = error.localizedDescription
                dismiss()
            }
            isLoading = false
        }
    }

    func dismiss() {
        isActive = false
        pages = []
        pageIndex = 0
        isLoading = false
    }

    func handlePageChange(_ index: Int) {
        pageIndex = index
        guard pages.indices.contains(index), pages[index].kind == .exit else { return }
        dismiss()
    }
}
