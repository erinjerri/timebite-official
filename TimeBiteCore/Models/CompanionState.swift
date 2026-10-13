import Foundation

/// Portable display projection. No Health samples, calendar titles, or account credentials.
public struct CompanionState: Codable, Equatable, Sendable {
    public var version = 1
    public var asOf: Date
    public var dayStart: Date
    public var dayEnd: Date
    public var active: CompanionAction?
    public var actions: [CompanionAction]
    public var periods: [CompanionPeriod]

    public init(summary: TodayActivitySummary, actions: [Action], sessions: [ActivitySession], at date: Date, calendar: Calendar = .current) {
        asOf = date; dayStart = summary.dayInterval.start; dayEnd = summary.dayInterval.end
        let current = sessions.first { $0.status != .completed }
        let available = actions.filter { $0.executionState != .completed }
        let prioritized = available.filter { $0.id == current?.actionID } + available.filter { $0.id != current?.actionID }
        self.actions = prioritized.prefix(50).map { action in
            CompanionAction(id: action.id, title: action.title, session: current?.actionID == action.id ? current : nil)
        }
        active = self.actions.first { $0.session != nil }
        let noon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: dayStart) ?? dayStart.addingTimeInterval(summary.dayInterval.duration / 2)
        periods = [("AM", DateInterval(start: dayStart, end: noon)), ("PM", DateInterval(start: noon, end: dayEnd)), ("Total", summary.dayInterval)].map { name, interval in
            let entries = summary.entries
            func duration(_ source: TodayActivitySource?) -> TimeInterval {
                IntervalAggregation.mergedDuration(entries.filter { source == nil || $0.source == source }.compactMap(\.occupiedInterval).map { $0.clamped(to: interval) })
            }
            return CompanionPeriod(name: name, budgetSeconds: interval.duration, capturedSeconds: duration(nil), healthSeconds: duration(.health), calendarSeconds: duration(.calendar), actionSeconds: duration(.timeBite))
        }
    }
    public func isStale(at date: Date = Date()) -> Bool { date.timeIntervalSince(asOf) > 120 || date >= dayEnd }
    public static func encoder() -> JSONEncoder { let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601; return e }
    public static func decoder() -> JSONDecoder { let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601; return d }
}

public struct CompanionAction: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var title: String
    public var session: ActivitySession?
}
public struct CompanionPeriod: Codable, Equatable, Sendable {
    public var name: String
    public var budgetSeconds: TimeInterval
    public var capturedSeconds: TimeInterval
    public var healthSeconds: TimeInterval
    public var calendarSeconds: TimeInterval
    public var actionSeconds: TimeInterval
}
public struct CompanionCommand: Codable, Equatable, Sendable {
    public var id: UUID
    public var type: String
    public var actionID: UUID
    public var sessionID: UUID?
    public var revision: UInt64?
    public init(type: String, action: CompanionAction) {
        id = UUID(); self.type = type; actionID = action.id
        sessionID = action.session?.id; revision = action.session?.revision
    }
}
