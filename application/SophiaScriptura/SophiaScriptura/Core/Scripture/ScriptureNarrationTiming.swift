import Foundation

enum ScriptureNarrationTimingValidation {
    struct ValidatedTiming: Sendable {
        let verseStarts: [(verse: Int, start: TimeInterval)]
    }

    enum Failure: Equatable, Error, Sendable {
        case emptyTimings
        case emptyVerses
        case countMismatch(expected: Int, actual: Int)
        case nonFiniteTimestamp
        case negativeTimestamp
        case nonMonotonicTimestamps
        case exceedsDuration(TimeInterval)
    }

    static func validate(
        startTimes: [TimeInterval],
        verseNumbers: [Int],
        duration: TimeInterval?
    ) -> Result<ValidatedTiming, Failure> {
        guard !verseNumbers.isEmpty else { return .failure(.emptyVerses) }
        guard !startTimes.isEmpty else { return .failure(.emptyTimings) }
        guard startTimes.count == verseNumbers.count else {
            return .failure(.countMismatch(expected: verseNumbers.count, actual: startTimes.count))
        }

        var pairs: [(verse: Int, start: TimeInterval)] = []
        pairs.reserveCapacity(startTimes.count)
        var previous = -Double.infinity

        for (index, rawStart) in startTimes.enumerated() {
            guard rawStart.isFinite else { return .failure(.nonFiniteTimestamp) }
            guard rawStart >= 0 else { return .failure(.negativeTimestamp) }
            if rawStart < previous { return .failure(.nonMonotonicTimestamps) }
            previous = rawStart
            pairs.append((verse: verseNumbers[index], start: rawStart))
        }

        if let duration, duration.isFinite, duration > 0 {
            if let last = pairs.last?.start, last > duration {
                return .failure(.exceedsDuration(duration))
            }
        }

        return .success(ValidatedTiming(verseStarts: pairs))
    }

    static func highlightedVerse(
        at time: TimeInterval,
        in timing: ValidatedTiming,
        duration: TimeInterval
    ) -> Int? {
        guard time.isFinite, time >= 0 else { return nil }
        let pairs = timing.verseStarts
        guard !pairs.isEmpty else { return nil }

        if time < pairs[0].start { return nil }

        var candidate: Int?
        for pair in pairs where pair.start <= time {
            candidate = pair.verse
        }
        if let candidate { return candidate }
        if duration.isFinite, time <= duration + 0.05, let last = pairs.last?.verse {
            return last
        }
        return nil
    }

    static func verseNumbers(from document: ChapterDocument) -> [Int] {
        document.verseNumbers
    }

    static func startTime(forVerse verse: Int, in timing: ValidatedTiming) -> TimeInterval? {
        timing.verseStarts.first(where: { $0.verse == verse })?.start
    }

    static func nextVerse(after verse: Int?, in timing: ValidatedTiming) -> Int? {
        let pairs = timing.verseStarts
        guard !pairs.isEmpty else { return nil }
        guard let verse else { return pairs[0].verse }
        guard let index = pairs.firstIndex(where: { $0.verse == verse }) else { return pairs[0].verse }
        let next = index + 1
        guard next < pairs.count else { return nil }
        return pairs[next].verse
    }

    static func previousVerse(before verse: Int?, in timing: ValidatedTiming) -> Int? {
        let pairs = timing.verseStarts
        guard !pairs.isEmpty else { return nil }
        guard let verse else { return nil }
        guard let index = pairs.firstIndex(where: { $0.verse == verse }) else { return nil }
        let previous = index - 1
        guard previous >= 0 else { return nil }
        return pairs[previous].verse
    }
}
