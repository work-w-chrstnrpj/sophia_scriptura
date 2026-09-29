import Foundation
import SwiftData

enum ReaderSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] { [ReaderRecord.self] }
    @Model final class ReaderRecord {
        @Attribute(.unique) var key: String
        var payload: Data
        init(key: String = "reader", payload: Data) { self.key = key; self.payload = payload }
    }
}

@MainActor final class ReaderStateStore: ReaderStateRepository {
    private let container: ModelContainer
    init(inMemory: Bool = false, storageName: String = "Reader-v1") throws {
        let schema = Schema(versionedSchema: ReaderSchemaV1.self)
        let configuration = ModelConfiguration(storageName, schema: schema, isStoredInMemoryOnly: inMemory, cloudKitDatabase: .none)
        container = try ModelContainer(for: schema, configurations: configuration)
    }
    private func context() -> ModelContext {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        return context
    }
    func load() throws -> ReaderSnapshot? {
        let context = context()
        let records = try context.fetch(FetchDescriptor<ReaderSchemaV1.ReaderRecord>())
        guard records.count <= 1 else { throw ScriptureError.persistence }
        guard let record = records.first else { return nil }
        let snapshot = try JSONDecoder().decode(ReaderSnapshot.self, from: record.payload)
        guard snapshot.schemaVersion == 1 else { throw ScriptureError.incompatibleSchema }
        return snapshot
    }
    func save(_ snapshot: ReaderSnapshot) throws {
        // Validate the existing record before touching it. A damaged/future record is never reset.
        _ = try load()
        let bytes = try JSONEncoder().encode(snapshot)
        let context = context()
        do {
            if let record = try context.fetch(FetchDescriptor<ReaderSchemaV1.ReaderRecord>()).first {
                record.payload = bytes
            } else { context.insert(ReaderSchemaV1.ReaderRecord(payload: bytes)) }
            try context.save()
        } catch { context.rollback(); throw error }
    }
}
