import Foundation

/// Lifecycle for longer-term outcomes and groupings.
public enum ItemStatus: String, Codable, Equatable, Sendable {
    case active
    case completed
    case cancelled
}

/// Planning/lifecycle status is independent from timer execution state.
public enum ActionStatus: String, Codable, Equatable, Sendable {
    case inbox
    case planned
    case active
    case completed
    case cancelled
}

public enum ExecutionState: String, Codable, Equatable, Sendable {
    case notStarted
    case running
    case paused
    case completed
}

/// Recoverable issues; drafts and decoded imports may temporarily be incomplete.
public enum ActionValidationIssue: Equatable, Sendable {
    case invalidPlannedDuration
    case invalidActualDuration
    case actualEndBeforeStart
    case projectIDMismatch
    case goalIDMismatch
}
