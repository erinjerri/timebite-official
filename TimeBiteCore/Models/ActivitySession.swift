import Foundation

public enum ActivitySessionStatus: String, Codable, Sendable {
    case running, paused, completed
}

public enum ActivitySessionError: Error, Equatable {
    case invalidTransition
    case timeBeforeCurrentSegment
    case invalidTargetDuration
}

/// An active interval is closed at pause or completion. Keeping intervals makes
/// daily totals correct even when a session crosses midnight or is paused overnight.
public struct ActiveInterval: Codable, Equatable, Sendable {
    public var start: Date
    public var end: Date

    public init(start: Date, end: Date) {
        self.start = start
        self.end = end
    }
}

public struct ActivitySession: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let actionID: UUID
    public let startedAt: Date
    public var pausedAt: Date?
    public var completedAt: Date?
    public private(set) var accumulatedDuration: TimeInterval
    public let targetDuration: TimeInterval
    public private(set) var status: ActivitySessionStatus
    public private(set) var runningSince: Date?
    public private(set) var activeIntervals: [ActiveInterval]
    /// Increments on every state transition for deterministic sync comparisons.
    public private(set) var revision: UInt64

    public init(
        id: UUID = UUID(), actionID: UUID, startedAt: Date,
        targetDuration: TimeInterval
    ) throws {
        guard targetDuration.isFinite, targetDuration > 0 else {
            throw ActivitySessionError.invalidTargetDuration
        }
        self.id = id
        self.actionID = actionID
        self.startedAt = startedAt
        self.targetDuration = targetDuration
        self.pausedAt = nil
        self.completedAt = nil
        self.accumulatedDuration = 0
        self.status = .running
        self.runningSince = startedAt
        self.activeIntervals = []
        self.revision = 0
    }

    public func elapsed(at date: Date) -> TimeInterval {
        accumulatedDuration + (runningSince.map { max(0, date.timeIntervalSince($0)) } ?? 0)
    }

    public var ringProgressAtCompletion: Double? {
        status == .completed ? 1 : nil
    }

    public func ringProgress(at date: Date) -> Double {
        if status == .completed { return 1 }
        return min(1, max(0, elapsed(at: date) / targetDuration))
    }

    public mutating func pause(at date: Date) throws {
        guard status == .running, let runningSince else { throw ActivitySessionError.invalidTransition }
        try closeInterval(from: runningSince, at: date)
        self.runningSince = nil
        self.pausedAt = date
        self.status = .paused
        revision += 1
    }

    public mutating func resume(at date: Date) throws {
        guard status == .paused, let pausedAt, date >= pausedAt else {
            throw ActivitySessionError.invalidTransition
        }
        self.pausedAt = nil
        self.runningSince = date
        self.status = .running
        revision += 1
    }

    /// Returns false for repeated completion, so callers can avoid double writes/counts.
    @discardableResult
    public mutating func complete(at date: Date) throws -> Bool {
        if status == .completed { return false }
        if let runningSince {
            try closeInterval(from: runningSince, at: date)
            self.runningSince = nil
        } else if let pausedAt, date < pausedAt {
            throw ActivitySessionError.timeBeforeCurrentSegment
        }
        self.pausedAt = nil
        self.completedAt = date
        self.status = .completed
        revision += 1
        return true
    }

    public func activeDuration(in interval: DateInterval, at date: Date) -> TimeInterval {
        let closed = activeIntervals.reduce(0) { sum, segment in
            sum + Self.overlap(segment.start, segment.end, interval)
        }
        guard let runningSince else { return closed }
        return closed + Self.overlap(runningSince, max(runningSince, date), interval)
    }

    private mutating func closeInterval(from start: Date, at end: Date) throws {
        guard end >= start else { throw ActivitySessionError.timeBeforeCurrentSegment }
        activeIntervals.append(ActiveInterval(start: start, end: end))
        accumulatedDuration += end.timeIntervalSince(start)
    }

    private static func overlap(_ start: Date, _ end: Date, _ interval: DateInterval) -> TimeInterval {
        max(0, min(end, interval.end).timeIntervalSince(max(start, interval.start)))
    }
}
