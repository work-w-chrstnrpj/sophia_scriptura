import Foundation

/// A local calendar schedule; the first Play anchors an undated strict Plan.
struct PlanSchedule: Codable, Equatable, Sendable {
    var startDate: Date?
    var timeZoneID = TimeZone.current.identifier
    var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: timeZoneID) ?? .current
        return value
    }
    func date(for index: Int) -> Date? {
        startDate.flatMap { calendar.date(byAdding: .day, value: index, to: calendar.startOfDay(for: $0)) }
    }
    func label(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar; formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "MMM. d, yyyy"
        return formatter.string(from: date)
    }
}

extension StudyPlan {
    var resolvedActivityModeID: String { activityModeID ?? ActivityModeID.reading.id }
    var completionDate: Date? { isComplete ? items.compactMap(\.completedAt).max() : nil }
    func dueDate(for index: Int) -> Date? {
        guard let strictSchedule, sections.indices.contains(index) else { return nil }
        return sections[index].dueDate ?? strictSchedule.date(for: index)
    }
    var dueDate: Date? { sections.indices.compactMap { dueDate(for: $0) }.max() }
    func completionDate(for index: Int) -> Date? {
        guard sections.indices.contains(index), !sections[index].items.isEmpty,
              sections[index].items.allSatisfy({ $0.completedAt != nil }) else { return nil }
        return sections[index].items.compactMap(\.completedAt).max()
    }
    func scheduleCaption(for index: Int? = nil) -> String? {
        guard let schedule = strictSchedule else { return nil }
        let due = index.map { dueDate(for: $0) } ?? dueDate
        let completed = index.map { completionDate(for: $0) } ?? completionDate
        return "Due date: \(due.map(schedule.label) ?? "Not scheduled")  ·  Completion date: \(completed.map(schedule.label) ?? "Not completed")"
    }
    func canCatchUp(now: Date = Date()) -> Bool {
        guard let schedule = strictSchedule else { return false }
        let today = schedule.calendar.startOfDay(for: now)
        return sections.indices.contains { index in
            !sections[index].items.isEmpty && completionDate(for: index) == nil
                && dueDate(for: index).map { $0 < today } == true
        }
    }
    /// An explicit action: keep completed dates/checks and rebase unfinished days in order.
    @discardableResult mutating func catchUp(now: Date = Date()) -> Bool {
        guard canCatchUp(now: now), let schedule = strictSchedule else { return false }
        let today = schedule.calendar.startOfDay(for: now)
        var offset = 0
        for index in sections.indices where completionDate(for: index) == nil {
            sections[index].dueDate = schedule.calendar.date(byAdding: .day, value: offset, to: today)
            offset += 1
        }
        return true
    }
    var playbackStartCursor: PlanCursor? { playbackStartCursor(in: nil) }
    /// Explicit day selection resumes its cursor/first unchecked assignment; completed days
    /// can be read again without erasing their original checks or completion dates.
    func playbackStartCursor(in sectionID: UUID?) -> PlanCursor? {
        let candidates = sections.filter { sectionID == nil || $0.id == sectionID }
        if let cursor, cursor.kind == .item,
           let section = candidates.first(where: { $0.id == cursor.sectionID }),
           section.items.contains(where: { $0.id == cursor.itemID }) { return cursor }
        for section in candidates {
            if let item = section.items.first(where: { $0.completedAt == nil }) ?? (sectionID == nil ? nil : section.items.first) {
                return .init(kind: .item, sectionID: section.id, itemID: item.id, editionID: preferredEditionID)
            }
        }
        return nil
    }
}
