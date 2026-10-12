import Foundation

struct SophyValidationContext: Equatable, Sendable {
    var destinationHandles: Set<String> = []
    var modeHandles: Set<String> = []
    var trackHandles: Set<String> = []
    var presetHandles: Set<String> = []
    var sourceHandles: Set<String> = []
    var quizTypes: Set<String> = []
    var difficulties: Set<String> = []
    var bookIDs: Set<String> = []
    var bookIDByTitle: [String: String] = [:]
    var editionAbbreviations: Set<String> = []
}

enum SophyResponseValidator {
    static let rawLimit = 64 * 1024
    static let messageLimit = 8_000
    static let userInputLimit = 8_000

    static func validate(_ data: Data, context: SophyValidationContext = SophyValidationContext()) throws -> SophyValidatedResponse {
        let object = try SophyJSON.object(from: data)
        let keys = Set(object.keys)
        let required: Set<String> = ["version", "kind", "message", "questions", "actions", "sourceHandles"]
        guard required.isSubset(of: keys) else { throw SophySafeError.malformedPlan }
        guard jsonVersion(object["version"]) == 1 else { throw SophySafeError.malformedPlan }
        let kindText = (object["kind"] as? String)?.lowercased()
        guard let kind = kindText.flatMap(SophyResponseKind.init(rawValue:)), kind != .enhancement else {
            throw SophySafeError.malformedPlan
        }
        guard let message = object["message"] as? String, message.count <= messageLimit else { throw SophySafeError.malformedPlan }
        let questions = try questions(object["questions"])
        let actions = try actions(object["actions"], context: context)
        let sources = try stringList(object["sourceHandles"], limit: 8)
        guard sources.allSatisfy({ context.sourceHandles.contains($0) }) else { throw SophySafeError.forgedHandle }
        switch kind {
        case .reply:
            guard questions.isEmpty, actions.isEmpty else { throw SophySafeError.invalidArguments }
        case .clarification:
            guard (1...3).contains(questions.count), actions.isEmpty else { throw SophySafeError.invalidArguments }
        case .plan:
            guard questions.isEmpty, (1...10).contains(actions.count) else { throw SophySafeError.invalidArguments }
        case .enhancement:
            throw SophySafeError.malformedPlan
        }
        return SophyValidatedResponse(kind: kind, message: message, questions: questions, actions: actions, sourceHandles: sources)
    }

    static func validateEnhancement(_ data: Data, operation: String) throws -> SophyEnhancementResult {
        let object = try SophyJSON.object(from: data)
        var allowed: Set<String> = ["version", "kind", "replacementText", "feedback"]
        if operation == "rate" { allowed.insert("scores") }
        guard Set(object.keys) == allowed else { throw SophySafeError.malformedPlan }
        guard jsonInt(object["version"]) == 1, object["kind"] as? String == "enhancement" else { throw SophySafeError.malformedPlan }
        guard let replacement = object["replacementText"] as? String, replacement.count <= 16_000 else { throw SophySafeError.malformedPlan }
        guard let feedback = object["feedback"] as? String, feedback.count <= 4_000 else { throw SophySafeError.malformedPlan }
        if operation == "rate" { throw SophySafeError.invalidArguments }
        guard object["scores"] == nil else { throw SophySafeError.invalidArguments }
        return SophyEnhancementResult(replacementText: replacement, feedback: feedback, scores: nil)
    }

    static func validateEnhancement(_ data: Data, ratingTarget: String) throws -> SophyEnhancementResult {
        let object = try SophyJSON.object(from: data)
        guard Set(object.keys) == ["version", "kind", "replacementText", "feedback", "scores"] else { throw SophySafeError.malformedPlan }
        guard jsonInt(object["version"]) == 1, object["kind"] as? String == "enhancement" else { throw SophySafeError.malformedPlan }
        guard let replacement = object["replacementText"] as? String, replacement.count <= 16_000 else { throw SophySafeError.malformedPlan }
        guard let feedback = object["feedback"] as? String, feedback.count <= 4_000 else { throw SophySafeError.malformedPlan }
        let scores = try ratingScores(object["scores"], target: ratingTarget)
        return SophyEnhancementResult(replacementText: replacement, feedback: feedback, scores: scores)
    }

    private static func questions(_ value: Any?) throws -> [SophyQuestion] {
        guard let rows = value as? [[String: Any]] else { throw SophySafeError.malformedPlan }
        return try rows.map { row in
            guard Set(row.keys).isSubset(of: ["field", "prompt", "choices"]) else { throw SophySafeError.malformedPlan }
            guard let field = row["field"] as? String, !field.isEmpty,
                  let prompt = row["prompt"] as? String, !prompt.isEmpty else { throw SophySafeError.invalidArguments }
            let choices: [String]
            if row["choices"] == nil || row["choices"] is NSNull {
                choices = []
            } else if let listed = row["choices"] as? [String], listed.count <= 6 {
                choices = listed
            } else {
                throw SophySafeError.invalidArguments
            }
            return SophyQuestion(field: field, prompt: prompt, choices: choices)
        }
    }

    private static func actions(_ value: Any?, context: SophyValidationContext) throws -> [SophyActionDraft] {
        guard let rows = value as? [[String: Any]] else { throw SophySafeError.malformedPlan }
        return try rows.map { try action($0, context: context) }
    }

    private static func action(_ row: [String: Any], context: SophyValidationContext) throws -> SophyActionDraft {
        guard Set(row.keys).isSubset(of: ["type", "arguments"]), let type = row["type"] as? String else {
            throw SophySafeError.malformedPlan
        }
        let arguments: [String: Any]
        if let decoded = row["arguments"] as? [String: Any] {
            arguments = decoded
        } else if let encoded = row["arguments"] as? String,
                  let data = encoded.data(using: .utf8),
                  let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            arguments = parsed
        } else {
            throw SophySafeError.malformedPlan
        }
        switch type.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "createfolders", "createfolder", "folders", "folder":
            return try folders(arguments, context: context)
        case "createreminder", "reminder":
            return try reminder(arguments, context: context)
        case "createactivity", "activity":
            return try activity(arguments, context: context)
        case "music":
            return try music(arguments, context: context)
        case "openquiz", "quiz":
            return try quiz(arguments, context: context)
        case "opencontemplation", "contemplation", "contemplate":
            return try contemplation(arguments)
        case "openchat", "chat":
            return try chat(arguments, context: context)
        case "openscripture", "scripture", "openpassage", "passage":
            return try openScripture(arguments, context: context)
        case "lookup", "search", "find":
            return try lookup(arguments)
        case "insights":
            return try insights(arguments, context: context)
        case "enhance":
            return try enhance(arguments)
        case "deletenote":
            throw SophySafeError.unknownAction
        default:
            throw SophySafeError.unknownAction
        }
    }

    private static func folders(_ arguments: [String: Any], context: SophyValidationContext) throws -> SophyActionDraft {
        guard Set(arguments.keys).isSubset(of: ["destinationHandle", "nodes"]), arguments["nodes"] != nil else { throw SophySafeError.invalidArguments }
        let destination = try nullableString(arguments["destinationHandle"])
        if let destination, !context.destinationHandles.contains(destination) { throw SophySafeError.forgedHandle }
        let rowList = try folderNodeRows(arguments["nodes"])
        guard (1...100).contains(rowList.count) else { throw SophySafeError.invalidArguments }
        var nodes: [SophyFolderNodeDraft] = []
        var keys = Set<String>()
        for row in rowList {
            guard Set(row.keys).isSubset(of: ["key", "parentKey", "name", "description"]), row["key"] != nil, row["name"] != nil else {
                throw SophySafeError.invalidArguments
            }
            guard let key = row["key"] as? String, !key.isEmpty, keys.insert(key).inserted else { throw SophySafeError.invalidArguments }
            let parent = try nullableString(row["parentKey"])
            let name = try bounded((row["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines), min: 1, max: 120)
            if name.localizedCaseInsensitiveCompare("No Folder") == .orderedSame { throw SophySafeError.invalidArguments }
            let description = try bounded(optionalString(row["description"]) ?? "", min: 0, max: 2_000)
            nodes.append(SophyFolderNodeDraft(key: key, parentKey: parent, name: name, description: description))
        }
        try validateTree(nodes)
        return .createFolders(destinationHandle: destination, nodes: nodes)
    }

    private static func folderNodeRows(_ value: Any?) throws -> [[String: Any]] {
        if let rows = value as? [[String: Any]] { return rows }
        if let row = value as? [String: Any] { return [row] }
        throw SophySafeError.invalidArguments
    }

    static func validateTree(_ nodes: [SophyFolderNodeDraft]) throws {
        let keys = Set(nodes.map(\.key))
        guard keys.count == nodes.count else { throw SophySafeError.invalidArguments }
        var depth: [String: Int] = [:]
        func depthOf(_ key: String, trail: Set<String>) throws -> Int {
            if let known = depth[key] { return known }
            guard let node = nodes.first(where: { $0.key == key }) else { throw SophySafeError.invalidArguments }
            guard !trail.contains(key) else { throw SophySafeError.invalidArguments }
            let value: Int
            if let parent = node.parentKey {
                guard keys.contains(parent) else { throw SophySafeError.invalidArguments }
                value = try depthOf(parent, trail: trail.union([key])) + 1
            } else {
                value = 1
            }
            guard value <= 8 else { throw SophySafeError.invalidArguments }
            depth[key] = value
            return value
        }
        for node in nodes { _ = try depthOf(node.key, trail: []) }
    }

    private static func reminder(_ arguments: [String: Any], context: SophyValidationContext) throws -> SophyActionDraft {
        let allowed: Set<String> = ["title", "description", "modeHandle", "localDate", "localTime", "repeatRule", "deleteAfterFiring"]
        guard arguments.keys.allSatisfy(allowed.contains), arguments["title"] != nil, arguments["modeHandle"] != nil,
              arguments["localDate"] != nil, arguments["localTime"] != nil, arguments["repeatRule"] != nil else {
            throw SophySafeError.invalidArguments
        }
        let title = try bounded((arguments["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines), min: 1, max: 200)
        let description = try bounded(optionalString(arguments["description"]) ?? "", min: 0, max: 2_000)
        let mode = try requiredHandle(arguments["modeHandle"], allowed: context.modeHandles)
        let date = try dateString(arguments["localDate"])
        let time = try timeString(arguments["localTime"])
        guard let rule = arguments["repeatRule"] as? String, ["once", "daily", "weekdays", "weekends", "weekly"].contains(rule) else {
            throw SophySafeError.unsupportedRecurrence
        }
        let deleteAfter = try optionalBool(arguments["deleteAfterFiring"]) ?? false
        return .createReminder(title: title, description: description, modeHandle: mode, localDate: date, localTime: time, repeatRule: rule, deleteAfterFiring: deleteAfter)
    }

    private static func activity(_ arguments: [String: Any], context: SophyValidationContext) throws -> SophyActionDraft {
        let allowed: Set<String> = ["title", "description", "modeHandle", "localDate", "localStartTime", "localEndDate", "localEndTime", "durationMinutes"]
        guard arguments.keys.allSatisfy(allowed.contains) else { throw SophySafeError.invalidArguments }
        let title = try bounded((arguments["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines), min: 1, max: 200)
        let description = try bounded(optionalString(arguments["description"]) ?? "", min: 0, max: 2_000)
        let mode = try requiredHandle(arguments["modeHandle"], allowed: context.modeHandles)
        let date = try dateString(arguments["localDate"])
        let start = try optionalClock(arguments["localStartTime"])
        let endDate = try optionalDate(arguments["localEndDate"])
        let end = try optionalClock(arguments["localEndTime"])
        let duration = try optionalInt(arguments["durationMinutes"])
        if let duration, duration <= 0 || duration > 24 * 60 { throw SophySafeError.invalidArguments }
        return .createActivity(title: title, description: description, modeHandle: mode, localDate: date, localStartTime: start, localEndDate: endDate, localEndTime: end, durationMinutes: duration)
    }

    private static func music(_ arguments: [String: Any], context: SophyValidationContext) throws -> SophyActionDraft {
        guard arguments.keys.allSatisfy(["operation", "trackHandle"].contains) else { throw SophySafeError.invalidArguments }
        guard let operation = arguments["operation"] as? String, ["play", "pause", "select"].contains(operation) else {
            throw SophySafeError.invalidArguments
        }
        let track = try optionalString(arguments["trackHandle"])
        switch operation {
        case "select":
            guard let track, context.trackHandles.contains(track) else { throw SophySafeError.forgedHandle }
        case "pause":
            guard track == nil else { throw SophySafeError.invalidArguments }
        default:
            if let track, !context.trackHandles.contains(track) { throw SophySafeError.forgedHandle }
        }
        return .music(operation: operation, trackHandle: track)
    }

    private static func quiz(_ arguments: [String: Any], context: SophyValidationContext) throws -> SophyActionDraft {
        guard arguments.keys.allSatisfy(["types", "difficulty", "timed"].contains) else { throw SophySafeError.invalidArguments }
        let types = try optionalStringList(arguments["types"])
        if let types, !types.allSatisfy({ context.quizTypes.contains($0) }) { throw SophySafeError.invalidArguments }
        let difficulty = try optionalString(arguments["difficulty"])
        if let difficulty, !context.difficulties.contains(difficulty) { throw SophySafeError.invalidArguments }
        let timed = try optionalBool(arguments["timed"])
        return .openQuiz(types: types, difficulty: difficulty, timed: timed)
    }

    private static func contemplation(_ arguments: [String: Any]) throws -> SophyActionDraft {
        guard arguments.keys.allSatisfy(["title", "passage"].contains) else { throw SophySafeError.invalidArguments }
        let title = try optionalString(arguments["title"])
        var passage: SophyPassageDraft?
        if arguments.keys.contains("passage"), !(arguments["passage"] is NSNull) {
            guard let row = arguments["passage"] as? [String: Any], Set(row.keys) == ["book", "chapter", "startVerse", "endVerse"],
                  let book = row["book"] as? String, !book.isEmpty,
                  let chapter = jsonInt(row["chapter"]), let start = jsonInt(row["startVerse"]), let end = jsonInt(row["endVerse"]),
                  chapter > 0, start > 0, end >= start else { throw SophySafeError.invalidArguments }
            passage = SophyPassageDraft(book: book, chapter: chapter, startVerse: start, endVerse: end)
        }
        return .openContemplation(title: title, passage: passage)
    }

    private static func chat(_ arguments: [String: Any], context: SophyValidationContext) throws -> SophyActionDraft {
        guard Set(arguments.keys) == ["presetHandle", "prompt"] else { throw SophySafeError.invalidArguments }
        let preset = try requiredHandle(arguments["presetHandle"], allowed: context.presetHandles)
        let prompt = try bounded(arguments["prompt"] as? String, min: 1, max: 8_000)
        return .openChat(presetHandle: preset, prompt: prompt)
    }

    private static func openScripture(_ arguments: [String: Any], context: SophyValidationContext) throws -> SophyActionDraft {
        guard arguments.keys.allSatisfy(["book", "chapter", "verse", "editionAbbreviation"].contains),
              let rawBook = arguments["book"] as? String, !rawBook.isEmpty else { throw SophySafeError.invalidArguments }
        let book = try resolveBookID(rawBook, context: context)
        let chapter = try optionalInt(arguments["chapter"]) ?? 1
        let verse = try optionalInt(arguments["verse"]) ?? 1
        guard (1...200).contains(chapter), (1...200).contains(verse) else { throw SophySafeError.invalidArguments }
        let edition = try optionalString(arguments["editionAbbreviation"])?.uppercased()
        if let edition, !edition.isEmpty, !context.editionAbbreviations.isEmpty,
           !context.editionAbbreviations.contains(edition) { throw SophySafeError.forgedHandle }
        return .openScripture(book: book, chapter: chapter, verse: verse, editionAbbreviation: edition?.isEmpty == false ? edition : nil)
    }

    private static func resolveBookID(_ raw: String, context: SophyValidationContext) throws -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if context.bookIDs.contains(trimmed) { return trimmed }
        if let id = context.bookIDs.first(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) { return id }
        if let id = context.bookIDByTitle[trimmed.lowercased()] { return id }
        throw SophySafeError.forgedHandle
    }

    private static func lookup(_ arguments: [String: Any]) throws -> SophyActionDraft {
        guard Set(arguments.keys) == ["query", "scope"] else { throw SophySafeError.invalidArguments }
        let query = try bounded((arguments["query"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines), min: 1, max: 1_000)
        guard let scope = arguments["scope"] as? String, ["notes", "collections", "both"].contains(scope) else {
            throw SophySafeError.invalidArguments
        }
        return .lookup(query: query, scope: scope)
    }

    private static func insights(_ arguments: [String: Any], context: SophyValidationContext) throws -> SophyActionDraft {
        guard arguments.keys.allSatisfy(["period", "anchorDate", "modeHandle"].contains), arguments["period"] != nil else {
            throw SophySafeError.invalidArguments
        }
        guard let period = arguments["period"] as? String, ["day", "week", "month", "year"].contains(period) else {
            throw SophySafeError.invalidArguments
        }
        let anchor = try optionalDate(arguments["anchorDate"])
        let mode = try optionalString(arguments["modeHandle"])
        if let mode, !context.modeHandles.contains(mode) { throw SophySafeError.forgedHandle }
        return .insights(period: period, anchorDate: anchor, modeHandle: mode)
    }

    private static func enhance(_ arguments: [String: Any]) throws -> SophyActionDraft {
        guard arguments.keys.allSatisfy(["operation", "tone", "ratingTarget"].contains), let operation = arguments["operation"] as? String,
              ["grammar", "tone", "organize", "expound", "rate"].contains(operation) else { throw SophySafeError.invalidArguments }
        let tone = try optionalString(arguments["tone"])
        let rating = try optionalString(arguments["ratingTarget"])
        if operation == "tone" {
            guard let tone, ["casual", "professional", "creative", "academic", "devotional"].contains(tone) else { throw SophySafeError.invalidArguments }
        } else if tone != nil {
            throw SophySafeError.invalidArguments
        }
        if operation == "rate" {
            guard let rating, ["grammar", "idea", "both"].contains(rating) else { throw SophySafeError.invalidArguments }
        } else if rating != nil {
            throw SophySafeError.invalidArguments
        }
        return .enhance(operation: operation, tone: tone, ratingTarget: rating)
    }

    private static func ratingScores(_ value: Any?, target: String?) throws -> SophyEnhancementScore {
        guard let row = value as? [String: Any] else { throw SophySafeError.malformedPlan }
        let grammar = try optionalScore(row["grammar"])
        let idea = try optionalScore(row["idea"])
        guard Set(row.keys).isSubset(of: ["grammar", "idea"]) else { throw SophySafeError.invalidArguments }
        if let target {
            switch target {
            case "grammar":
                guard grammar != nil, idea == nil, !row.keys.contains("idea") else { throw SophySafeError.invalidArguments }
            case "idea":
                guard idea != nil, grammar == nil, !row.keys.contains("grammar") else { throw SophySafeError.invalidArguments }
            case "both":
                guard grammar != nil, idea != nil else { throw SophySafeError.invalidArguments }
            default:
                throw SophySafeError.invalidArguments
            }
        }
        return SophyEnhancementScore(grammar: grammar, idea: idea)
    }

    private static func optionalScore(_ value: Any?) throws -> Double? {
        if value == nil || value is NSNull { return nil }
        guard let number = value as? NSNumber else { throw SophySafeError.invalidArguments }
        let score = number.doubleValue
        guard (0...10).contains(score) else { throw SophySafeError.invalidArguments }
        return score
    }

    private static func stringList(_ value: Any?, limit: Int) throws -> [String] {
        guard let values = value as? [String], values.count <= limit else { throw SophySafeError.malformedPlan }
        return values
    }

    private static func optionalStringList(_ value: Any?) throws -> [String]? {
        if value == nil || value is NSNull { return nil }
        guard let values = value as? [String] else { throw SophySafeError.invalidArguments }
        return values
    }

    private static func requiredHandle(_ value: Any?, allowed: Set<String>) throws -> String {
        guard let handle = value as? String, allowed.contains(handle) else { throw SophySafeError.forgedHandle }
        return handle
    }

    private static func bounded(_ value: String?, min: Int, max: Int) throws -> String {
        if min == 0, value == nil || value?.isEmpty == true { return value ?? "" }
        guard let value, value.count >= min, value.count <= max else { throw SophySafeError.invalidArguments }
        return value
    }

    private static func optionalString(_ value: Any?) throws -> String? {
        if value == nil || value is NSNull { return nil }
        guard let string = value as? String else { throw SophySafeError.invalidArguments }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func nullableString(_ value: Any?) throws -> String? {
        try optionalString(value)
    }

    private static func optionalBool(_ value: Any?) throws -> Bool? {
        if value == nil { return nil }
        if value is NSNull { throw SophySafeError.invalidArguments }
        guard let number = value as? NSNumber, CFGetTypeID(number) == CFBooleanGetTypeID() else { throw SophySafeError.invalidArguments }
        return number.boolValue
    }

    private static func optionalInt(_ value: Any?) throws -> Int? {
        if value == nil || value is NSNull { return nil }
        guard let int = jsonInt(value) else { throw SophySafeError.invalidArguments }
        return int
    }

    private static func dateString(_ value: Any?) throws -> String {
        guard let text = value as? String, dateOK(text) else { throw SophySafeError.invalidArguments }
        return text
    }

    private static func optionalDate(_ value: Any?) throws -> String? {
        if value == nil { return nil }
        if value is NSNull { throw SophySafeError.invalidArguments }
        return try dateString(value)
    }

    private static func timeString(_ value: Any?) throws -> String {
        guard let text = value as? String, timeOK(text) else { throw SophySafeError.invalidArguments }
        return text
    }

    private static func optionalClock(_ value: Any?) throws -> String? {
        if value == nil { return nil }
        if value is NSNull { throw SophySafeError.invalidArguments }
        return try timeString(value)
    }

    private static func dateOK(_ text: String) -> Bool {
        guard text.count == 10, text.contains("-") else { return false }
        let parts = text.split(separator: "-")
        guard parts.count == 3, let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]) else { return false }
        return (1...9999).contains(year) && (1...12).contains(month) && (1...31).contains(day)
    }

    private static func timeOK(_ text: String) -> Bool {
        let parts = text.split(separator: ":")
        guard parts.count == 2, let hour = Int(parts[0]), let minute = Int(parts[1]), parts[0].count == 2, parts[1].count == 2 else { return false }
        return (0...23).contains(hour) && (0...59).contains(minute)
    }

    private static func jsonInt(_ value: Any?) -> Int? {
        if let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() {
            let int = number.intValue
            return number.doubleValue == Double(int) ? int : nil
        }
        if let text = value as? String, let int = Int(text.trimmingCharacters(in: .whitespacesAndNewlines)) { return int }
        return nil
    }

    private static func jsonVersion(_ value: Any?) -> Int? {
        jsonInt(value) ?? (value as? String).flatMap { jsonInt($0) }
    }
}

enum SophyJSON {
    /// Strips markdown fences and surrounding prose so provider output still validates.
    static func normalizedPayload(from raw: String) throws -> Data {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.contains("```") {
            if let fenced = fencedJSON(in: text) { text = fenced }
            else { text = text.replacingOccurrences(of: "```json", with: "").replacingOccurrences(of: "```", with: "") }
        }
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let extracted = extractJSONObject(from: text) {
            text = extracted
        } else if text.first != "{" || text.last != "}" {
            throw SophySafeError.malformedPlan
        }
        guard text.utf8.count <= SophyResponseValidator.rawLimit else { throw SophySafeError.malformedPlan }
        let data = Data(text.utf8)
        try rejectDuplicateKeys(data)
        return data
    }

    static func object(from data: Data) throws -> [String: Any] {
        guard data.count <= SophyResponseValidator.rawLimit else { throw SophySafeError.malformedPlan }
        guard let text = String(data: data, encoding: .utf8) else { throw SophySafeError.malformedPlan }
        let payload = try normalizedPayload(from: text)
        let parsed = try JSONSerialization.jsonObject(with: payload)
        guard let object = parsed as? [String: Any] else { throw SophySafeError.malformedPlan }
        return object
    }

    /// First balanced `{...}` slice, respecting quoted strings (more reliable than last-`}` trimming).
    static func extractJSONObject(from text: String) -> String? {
        guard let start = text.firstIndex(of: "{") else { return nil }
        var depth = 0
        var inString = false
        var escaped = false
        for index in text.indices[start...] {
            let character = text[index]
            if inString {
                if escaped { escaped = false; continue }
                if character == "\\" { escaped = true; continue }
                if character == "\"" { inString = false }
                continue
            }
            if character == "\"" { inString = true; continue }
            if character == "{" { depth += 1 }
            if character == "}" {
                depth -= 1
                if depth == 0 { return String(text[start...index]) }
            }
        }
        return nil
    }

    private static func fencedJSON(in text: String) -> String? {
        guard let open = text.range(of: "```") else { return nil }
        var cursor = open.upperBound
        if text[cursor...].hasPrefix("json") { cursor = text.index(cursor, offsetBy: 4) }
        if cursor < text.endIndex, text[cursor] == "\n" { cursor = text.index(after: cursor) }
        guard let close = text[cursor...].range(of: "```") else { return nil }
        return String(text[cursor..<close.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func rejectDuplicateKeys(_ data: Data) throws {
        var parser = Parser(Array(String(decoding: data, as: UTF8.self)))
        try parser.parseValue()
        parser.skipWhitespace()
        guard parser.ended else { throw SophySafeError.malformedPlan }
    }

    private struct Parser {
        var characters: [Character]
        var index = 0
        var ended: Bool { index >= characters.count }

        init(_ characters: [Character]) { self.characters = characters }

        mutating func parseValue() throws {
            skipWhitespace()
            guard let character = peek() else { throw SophySafeError.malformedPlan }
            switch character {
            case "{": try parseObject()
            case "[": try parseArray()
            case "\"": _ = try parseString()
            case "t": try consume("true")
            case "f": try consume("false")
            case "n": try consume("null")
            default: try parseNumber()
            }
        }

        mutating func parseObject() throws {
            try consume("{")
            skipWhitespace()
            var keys = Set<String>()
            if peek() == "}" { try consume("}"); return }
            while true {
                skipWhitespace()
                let key = try parseString()
                guard keys.insert(key).inserted else { throw SophySafeError.malformedPlan }
                skipWhitespace()
                try consume(":")
                try parseValue()
                skipWhitespace()
                if peek() == "," {
                    try consume(",")
                    skipWhitespace()
                    if peek() == "}" { try consume("}"); return }
                    continue
                }
                try consume("}")
                return
            }
        }

        mutating func parseArray() throws {
            try consume("[")
            skipWhitespace()
            if peek() == "]" { try consume("]"); return }
            while true {
                try parseValue()
                skipWhitespace()
                if peek() == "," {
                    try consume(",")
                    skipWhitespace()
                    if peek() == "]" { try consume("]"); return }
                    continue
                }
                try consume("]")
                return
            }
        }

        mutating func parseString() throws -> String {
            try consume("\"")
            var value = ""
            while let character = peek() {
                advance()
                if character == "\"" { return value }
                if character == "\\" {
                    guard let escaped = peek() else { throw SophySafeError.malformedPlan }
                    advance()
                    value.append(escaped)
                } else {
                    value.append(character)
                }
            }
            throw SophySafeError.malformedPlan
        }

        mutating func parseNumber() throws {
            guard let character = peek(), character == "-" || character.isNumber else { throw SophySafeError.malformedPlan }
            if character == "-" { advance() }
            while let next = peek(), next.isNumber || next == "." || next == "e" || next == "E" || next == "+" || next == "-" {
                advance()
            }
        }

        mutating func consume(_ text: String) throws {
            for character in text {
                guard peek() == character else { throw SophySafeError.malformedPlan }
                advance()
            }
        }

        mutating func skipWhitespace() {
            while let character = peek(), character.isWhitespace { advance() }
        }

        func peek() -> Character? { ended ? nil : characters[index] }

        mutating func advance() { index += 1 }
    }
}
