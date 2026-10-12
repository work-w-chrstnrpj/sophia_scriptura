import Foundation

/// Maps app edition IDs to canonical reference-system IDs. Unknown editions never receive a WEB fallback.
enum ScriptureReferenceIdentity {
    static let bundledEditionID = "web.engwebp"
    static let bundledReferenceSystemID = "org.sophia.web.engwebp"

    static func translationSourceID(forEditionID editionID: String) -> TranslationSourceID? {
        if editionID == bundledEditionID { return .bundledWeb }
        if editionID.hasPrefix("api.bible.") { return .apiBible }
        if editionID.hasPrefix("helloao.") { return .helloAO }
        return nil
    }

    /// Known edition → reference-system mapping. Returns `nil` for unrecognized edition IDs.
    static func referenceSystemID(forEditionID editionID: String) -> String? {
        switch translationSourceID(forEditionID: editionID) {
        case .bundledWeb:
            return bundledReferenceSystemID
        case .apiBible, .helloAO:
            return "org.sophia." + editionID
        case nil:
            return nil
        }
    }

    /// Resolves persisted or legacy identity. Validates an explicit stored value against known editions; preserves explicit identity for future sources.
    static func resolvedReferenceSystemID(editionID: String, stored explicit: String?) throws -> String {
        if let explicit {
            if let expected = referenceSystemID(forEditionID: editionID), explicit != expected {
                throw ScriptureError.incompatibleSchema
            }
            return explicit
        }
        guard let legacy = referenceSystemID(forEditionID: editionID) else {
            throw ScriptureError.incompatibleSchema
        }
        return legacy
    }
}
