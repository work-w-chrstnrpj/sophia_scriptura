import XCTest
@testable import SophiaScriptura

final class SophyPersistenceTests: XCTestCase {
    private var directory: URL!

    override func setUp() {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("sophy-tests-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: directory)
    }

    func testHistoryRoundTripRejectsSensitivePayloadAndRecoversPrevious() async throws {
        let repository = SophyFileRepository(directory: directory)
        let entry = SophyHistoryEntry(id: UUID(), createdAt: Date(timeIntervalSince1970: 10), actionType: "createReminder", status: "committed", resultIDs: [UUID()], resultCount: 1)
        try await repository.saveHistory([entry])
        try await repository.saveHistory([entry])
        let loaded = try await repository.loadHistory()
        XCTAssertEqual(loaded.value, [entry])
        XCTAssertFalse(loaded.recovered)

        let encoded = try JSONEncoder().encode(entry)
        XCTAssertFalse(String(decoding: encoded, as: UTF8.self).localizedCaseInsensitiveContains("prompt"))

        let current = directory.appendingPathComponent("history", isDirectory: true).appendingPathComponent("current.json")
        try Data("not-json".utf8).write(to: current)
        let recovered = try await repository.loadHistory()
        XCTAssertTrue(recovered.recovered)
        XCTAssertEqual(recovered.value, [entry])
    }

    func testBothCorruptGenerationsDisableMutationWithoutReplayPayload() async throws {
        let repository = SophyFileRepository(directory: directory)
        let entry = SophyJournalEntry(id: UUID(), planID: UUID(), actionType: "createActivity", resultIDs: [UUID()], state: .prepared, createdAt: Date(), updatedAt: Date(), safeErrorCode: nil)
        try await repository.saveJournal([entry])
        let base = directory.appendingPathComponent("journal", isDirectory: true)
        try Data("bad-current".utf8).write(to: base.appendingPathComponent("current.json"))
        try Data("bad-previous".utf8).write(to: base.appendingPathComponent("previous.json"))
        let loaded = try await repository.loadJournal()
        XCTAssertTrue(loaded.mutationsDisabled)
        XCTAssertTrue(loaded.value.isEmpty)
        do {
            try await repository.saveJournal([])
            XCTFail("Expected mutations to stay disabled")
        } catch {
            XCTAssertEqual(error as? SophySafeError, .writeFailed)
        }
        let damaged = try FileManager.default.contentsOfDirectory(at: base, includingPropertiesForKeys: nil)
        XCTAssertTrue(damaged.contains { $0.lastPathComponent.hasPrefix("damaged-") })
    }

    func testDeleteAllRemovesHistoryAndJournal() async throws {
        let repository = SophyFileRepository(directory: directory)
        try await repository.saveHistory([SophyHistoryEntry(id: UUID(), createdAt: Date(), actionType: "lookup", status: "committed", resultIDs: [], resultCount: 0)])
        try await repository.deleteAll()
        let loaded = try await repository.loadHistory()
        XCTAssertTrue(loaded.value.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.path))
    }
}
