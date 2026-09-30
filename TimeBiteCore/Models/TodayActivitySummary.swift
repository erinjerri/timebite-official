import Foundation

public enum TodayActivitySource: String, Codable, Equatable, Sendable {
    case timeBite = "TimeBite"
    case calendar = "Calendar"
    case health = "Health"
}

public struct TodayActivityEntry: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let source: TodayActivitySource
    public let startDate: Date?
    public let endDate: Date?
    public let duration: TimeInterval

    public init(
        id: String,
        title: String,
        source: TodayActivitySource,
        startDate: Date?,
        endDate: Date?,
        duration: TimeInterval
    ) {
        self.id = id
        self.title = title
        self.source = source
        self.startDate = startDate
        self.endDate = endDate
        self.duration = max(0, duration)
    }

    public var occupiedInterval: DateInterval? {
        guard let startDate, let endDate, endDate > startDate else { return nil }
        return DateInterval(start: startDate, end: endDate)
    }
}

public struct TodayActivitySummary: Equatable, Sendable {
    public let dayInterval: DateInterval
    public let entries: [TodayActivityEntry]
    public let trackedDuration: TimeInterval
    public let sourceDuration: TimeInterval

    public var trackedDayProgress: Double {
        let dayDuration = dayInterval.duration
        guard dayDuration > 0 else { return 0 }
        return min(1, max(0, trackedDuration / dayDuration))
    }

    public init(dayInterval: DateInterval, entries: [TodayActivityEntry]) {
        self.dayInterval = dayInterval
        self.entries = entries
        self.sourceDuration = entries.reduce(0) { $0 + max(0, $1.duration) }
        let occupied = entries.compactMap(\.occupiedInterval).map { $0.clamped(to: dayInterval) }
        self.trackedDuration = IntervalAggregation.mergedDuration(occupied)
    }

    public static func calculate(
        actions: [Action],
        sessions: [ActivitySession],
        healthRecords: [HealthActivityRecord],
        calendarEntries: [TodayActivityEntry] = [],
        at date: Date,
        calendar: Calendar = .current
    ) -> TodayActivitySummary {
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)
        let day = DateInterval(start: start, end: end)

        let timeBiteEntries = manualEntries(actions: actions, sessions: sessions, day: day, now: date)
        let healthEntries = healthRecords.deduplicatedByExternalIdentifier().compactMap { record -> TodayActivityEntry? in
            let interval = DateInterval(start: record.startDate, end: record.endDate).clamped(to: day)
            guard interval.duration > 0 else { return nil }
            return TodayActivityEntry(
                id: "health:\(record.externalIdentifier)",
                title: record.title,
                source: .health,
                startDate: interval.start,
                endDate: interval.end,
                duration: interval.duration
            )
        }
        let calendarToday = calendarEntries.compactMap { entry -> TodayActivityEntry? in
            guard let interval = entry.occupiedInterval?.clamped(to: day), interval.duration > 0 else {
                return nil
            }
            return TodayActivityEntry(
                id: entry.id,
                title: entry.title,
                source: .calendar,
                startDate: interval.start,
                endDate: interval.end,
                duration: interval.duration
            )
        }
        return TodayActivitySummary(dayInterval: day, entries: timeBiteEntries + calendarToday + healthEntries)
    }

    private static func manualEntries(
        actions: [Action],
        sessions: [ActivitySession],
        day: DateInterval,
        now: Date
    ) -> [TodayActivityEntry] {
        actions.compactMap { action in
            let matching = sessions.filter { $0.actionID == action.id }
            if let session = matching.first(where: { $0.status != .completed }) ?? matching.first(where: { $0.completedAt != nil }) {
                let end = session.completedAt ?? now
                let interval = DateInterval(start: session.startedAt, end: max(end, session.startedAt)).clamped(to: day)
                guard interval.duration > 0 else { return nil }
                return TodayActivityEntry(
                    id: "timebite:\(action.id.uuidString)",
                    title: action.title,
                    source: .timeBite,
                    startDate: interval.start,
                    endDate: interval.end,
                    duration: session.activeDuration(in: day, at: now)
                )
            }
            guard day.contains(action.plannedStart ?? action.createdAt) else { return nil }
            return TodayActivityEntry(
                id: "timebite:\(action.id.uuidString)",
                title: action.title,
                source: .timeBite,
                startDate: nil,
                endDate: nil,
                duration: action.plannedDuration ?? 0
            )
        }
    }
}

public enum IntervalAggregation {
    public static func mergedDuration(_ intervals: [DateInterval]) -> TimeInterval {
        let sorted = intervals
            .filter { $0.duration > 0 }
            .sorted { $0.start < $1.start }
        guard var current = sorted.first else { return 0 }
        var total: TimeInterval = 0
        for interval in sorted.dropFirst() {
            if interval.start <= current.end {
                current = DateInterval(start: current.start, end: max(current.end, interval.end))
            } else {
                total += current.duration
                current = interval
            }
        }
        return total + current.duration
    }
}

public extension DateInterval {
    func clamped(to boundary: DateInterval) -> DateInterval {
        let start = max(self.start, boundary.start)
        let end = min(self.end, boundary.end)
        return DateInterval(start: start, end: max(start, end))
    }
}

public extension Array where Element == HealthActivityRecord {
    func deduplicatedByExternalIdentifier() -> [HealthActivityRecord] {
        var seen = Set<String>()
        return filter { record in
            seen.insert(record.externalIdentifier).inserted
        }
    }
}

