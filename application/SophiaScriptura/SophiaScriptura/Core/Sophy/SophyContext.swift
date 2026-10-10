import Foundation
import CryptoKit

struct SophyContextSource: Equatable, Sendable {
    var handle: String
    var id: UUID
    var title: String
    var excerpt: String
}

struct SophyTurn: Identifiable, Equatable, Sendable {
    var id: UUID
    var role: String
    var text: String
}

enum SophyContextBuilder {
    static let sourceLimit = 8
    static let charactersPerSource = 4_000
    static let totalCharacters = 16_000
    static let turnLimit = 20
    static let turnCharacters = 24_000

    static func sources(from records: [SophyEligibleRecord]) -> [SophyContextSource] {
        let excluded = SophyEligibility.excludedIDs(records)
        let eligible = records
            .filter { !excluded.contains($0.id) && !$0.isVirtualUnfiled }
            .sorted { $0.modifiedAt == $1.modifiedAt ? $0.id.uuidString < $1.id.uuidString : $0.modifiedAt > $1.modifiedAt }
        return pack(eligible)
    }

    static func sources(matching query: String, in records: [SophyEligibleRecord]) -> [SophyContextSource] {
        pack(SophyEligibility.search(records, query: query, limit: sourceLimit))
    }

    static func boundedTurns(_ turns: [SophyTurn]) -> [SophyTurn] {
        var kept: [SophyTurn] = []
        var count = 0
        for turn in turns.reversed() {
            let next = count + turn.text.count
            if kept.count >= turnLimit || next > turnCharacters { break }
            kept.append(turn)
            count = next
        }
        return kept.reversed()
    }

    static func digest(_ text: String) -> String {
        SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private static func pack(_ records: [SophyEligibleRecord]) -> [SophyContextSource] {
        var noteCount = 0
        var collectionCount = 0
        var used = 0
        var sources: [SophyContextSource] = []
        for record in records {
            if sources.count >= sourceLimit { break }
            let excerpt = String(record.body.prefix(charactersPerSource))
            if used + excerpt.count > totalCharacters && !sources.isEmpty { break }
            let handle: String
            switch record.kind {
            case .note:
                noteCount += 1
                handle = "n\(noteCount)"
            case .collection:
                collectionCount += 1
                handle = "c\(collectionCount)"
            }
            used += excerpt.count
            sources.append(SophyContextSource(handle: handle, id: record.id, title: record.title, excerpt: excerpt))
        }
        return sources
    }
}
