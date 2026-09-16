import Foundation

public struct DailyProgress: Equatable, Sendable {
    public let dayStart: Date
    public let plannedDuration: TimeInterval
    public let executedDuration: TimeInterval
    public let creditedDuration: TimeInterval
    public let completedActions: Int
    public let currentActiveSessionID: UUID?

    public var ringProgress: Double {
        guard plannedDuration > 0 else { return creditedDuration > 0 ? 1 : 0 }
        return min(1, max(0, creditedDuration / plannedDuration))
    }

    /// Each completed action is counted once, even if several sessions exist.
    /// Completion credits its target allocation to the ring while actual time
    /// remains separately reported as executedDuration.
    public static func calculate(
        actions: [Action], sessions: [ActivitySession], at date: Date,
        calendar: Calendar = .current
    ) -> DailyProgress {
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)
        let day = DateInterval(start: start, end: end)
        let todayActions = actions.filter {
            day.contains($0.plannedStart ?? $0.createdAt)
        }
        let actionIDs = Set(todayActions.map(\.id))
        let planned = todayActions.reduce(0.0) { sum, action in
            let duration = action.plannedDuration ?? 0
            return sum + (duration.isFinite ? max(0, duration) : 0)
        }
        let relevant = sessions.filter { actionIDs.contains($0.actionID) }
        let executed = relevant.reduce(0.0) { $0 + $1.activeDuration(in: day, at: date) }
        let completedIDs = Set(relevant.compactMap { session -> UUID? in
            guard let completedAt = session.completedAt, day.contains(completedAt) else { return nil }
            return session.actionID
        })
        let credited = todayActions.reduce(0.0) { sum, action in
            let actionExecuted = relevant.filter { $0.actionID == action.id }
                .reduce(0.0) { $0 + $1.activeDuration(in: day, at: date) }
            let target = completedIDs.contains(action.id) ? max(0, action.plannedDuration ?? 0) : 0
            return sum + max(actionExecuted, target)
        }
        let activeID = relevant.first { $0.status == .running || $0.status == .paused }?.id
        return DailyProgress(
            dayStart: start, plannedDuration: planned,
            executedDuration: executed,
            creditedDuration: credited,
            completedActions: completedIDs.count,
            currentActiveSessionID: activeID
        )
    }
}
