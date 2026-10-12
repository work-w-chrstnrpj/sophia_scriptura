import Foundation

enum TranslationSourceID: String, Codable, Sendable, CaseIterable {
    case bundledWeb = "bundled-web"
    case apiBible = "api-bible"
    case helloAO = "helloao"
}

enum TranslationRightsDecision: String, Codable, Sendable {
    case allowed
    case denied
    case needsReview
}

struct TranslationRightsPolicy: Codable, Sendable, Equatable {
    var offlineRead: TranslationRightsDecision
    var copy: TranslationRightsDecision
    var share: TranslationRightsDecision
    var drag: TranslationRightsDecision
    var saveQuote: TranslationRightsDecision
    var aiContext: TranslationRightsDecision

    static let bundledPublicDomain = TranslationRightsPolicy(
        offlineRead: .allowed, copy: .allowed, share: .allowed, drag: .allowed, saveQuote: .allowed, aiContext: .allowed
    )
    static let apiBibleLicensed = TranslationRightsPolicy(
        offlineRead: .allowed, copy: .needsReview, share: .needsReview, drag: .needsReview,
        saveQuote: .needsReview, aiContext: .needsReview
    )
    static let helloAOUnavailable = TranslationRightsPolicy(
        offlineRead: .denied, copy: .denied, share: .denied, drag: .denied, saveQuote: .denied, aiContext: .denied
    )
}

struct TranslationDescriptor: Codable, Sendable, Equatable, Identifiable {
    var id: String { appEditionID }
    let sourceID: TranslationSourceID
    let appEditionID: String
    let referenceSystemID: String
    let name: String
    let abbreviation: String
    let attribution: String
    let rightsPolicy: TranslationRightsPolicy

    static func bundledWEBP() -> TranslationDescriptor {
        TranslationDescriptor(
            sourceID: .bundledWeb,
            appEditionID: ScriptureReferenceIdentity.bundledEditionID,
            referenceSystemID: ScriptureReferenceIdentity.bundledReferenceSystemID,
            name: "World English Bible",
            abbreviation: "WEB",
            attribution: "Public Domain",
            rightsPolicy: .bundledPublicDomain
        )
    }
}

enum ScriptureOperation: String, Codable, Sendable {
    case offlineRead
    case copy
    case share
    case drag
    case saveQuote
    case aiContext
}

enum TranslationRightsPolicyResolver {
    static func policy(forEditionID editionID: String) -> TranslationRightsPolicy? {
        switch ScriptureReferenceIdentity.translationSourceID(forEditionID: editionID) {
        case .bundledWeb: return .bundledPublicDomain
        case .apiBible: return .apiBibleLicensed
        case .helloAO:
            return HelloAOEligibility.edition(appEditionID: editionID)?.rightsPolicy ?? .helloAOUnavailable
        case nil: return nil
        }
    }

    static func descriptor(forEditionID editionID: String) -> TranslationDescriptor? {
        guard let sourceID = ScriptureReferenceIdentity.translationSourceID(forEditionID: editionID),
              let referenceSystemID = ScriptureReferenceIdentity.referenceSystemID(forEditionID: editionID),
              let policy = policy(forEditionID: editionID) else { return nil }
        if sourceID == .bundledWeb { return .bundledWEBP() }
        if let eligible = HelloAOEligibility.edition(appEditionID: editionID) {
            return TranslationDescriptor(
                sourceID: sourceID,
                appEditionID: editionID,
                referenceSystemID: referenceSystemID,
                name: eligible.name,
                abbreviation: eligible.abbreviation,
                attribution: eligible.attribution,
                rightsPolicy: policy
            )
        }
        return TranslationDescriptor(
            sourceID: sourceID,
            appEditionID: editionID,
            referenceSystemID: referenceSystemID,
            name: editionID,
            abbreviation: editionID,
            attribution: "",
            rightsPolicy: policy
        )
    }
}
