import Foundation

struct HelloAOEligibilityManifest: Codable, Sendable {
    let schemaVersion: Int
    let reviewedAt: String
    let editions: [HelloAOEligibleEdition]
}

struct HelloAOEligibleEdition: Codable, Sendable, Identifiable {
    struct PermittedOperations: Codable, Sendable {
        let install: Bool
        let offlineRead: Bool
        let copy: Bool
        let share: Bool
        let saveQuote: Bool
        let aiContext: Bool
    }

    var id: String { providerEditionID }
    let providerEditionID: String
    let appEditionID: String
    let name: String
    let abbreviation: String
    let language: String
    let expectedBookCount: Int
    let rightsEvidenceURLs: [String]
    let licenseSummary: String
    let attribution: String
    let permittedOperations: PermittedOperations

    var rightsPolicy: TranslationRightsPolicy {
        func decision(_ allowed: Bool) -> TranslationRightsDecision { allowed ? .allowed : .denied }
        return TranslationRightsPolicy(
            offlineRead: decision(permittedOperations.offlineRead),
            copy: decision(permittedOperations.copy),
            share: decision(permittedOperations.share),
            drag: decision(permittedOperations.copy),
            saveQuote: decision(permittedOperations.saveQuote),
            aiContext: decision(permittedOperations.aiContext)
        )
    }
}

enum HelloAOEligibility {
    private static let cached: HelloAOEligibilityManifest? = {
        let candidates = [
            Bundle.main.url(forResource: "helloao-eligibility", withExtension: "json", subdirectory: "Scripture"),
            Bundle.main.url(forResource: "helloao-eligibility", withExtension: "json", subdirectory: "Resources/Scripture"),
            Bundle.main.url(forResource: "helloao-eligibility", withExtension: "json")
        ]
        guard let url = candidates.compactMap({ $0 }).first,
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(HelloAOEligibilityManifest.self, from: data)
    }()

    static var manifest: HelloAOEligibilityManifest {
        guard let cached else {
            return HelloAOEligibilityManifest(schemaVersion: 1, reviewedAt: "", editions: [])
        }
        return cached
    }

    static func edition(providerID: String) -> HelloAOEligibleEdition? {
        manifest.editions.first { $0.providerEditionID == providerID }
    }

    static func edition(appEditionID: String) -> HelloAOEligibleEdition? {
        manifest.editions.first { $0.appEditionID == appEditionID }
    }

    static func providerEditionID(appEditionID: String) -> String? {
        edition(appEditionID: appEditionID)?.providerEditionID
    }
}

enum HelloAOBooks {
    static let deuterocanonIDs: Set<String> = [
        "TOB", "JDT", "ESG", "WIS", "SIR", "BAR", "1MA", "2MA", "3MA", "4MA",
        "1ES", "2ES", "MAN", "PS2", "DAG"
    ]

    static func testament(bookIndex: Int, totalBooks: Int, bookID: String) -> String {
        if totalBooks > 66, deuterocanonIDs.contains(bookID) { return "DC" }
        if bookIndex < 39 { return "OT" }
        return "NT"
    }
}
