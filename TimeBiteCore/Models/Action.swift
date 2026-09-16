import Foundation

/// A standalone unit of intent and execution, optionally grouped by project or goal.
public struct Action: TimeBiteItem {
    public let id: UUID
    public var title: String
    public var notes: String?
    public var goalID: UUID?
    public var projectID: UUID?

    public var plannedStart: Date?
    /// Seconds; nil means unknown, zero is valid. See validationIssues(project:).
    public var plannedDuration: TimeInterval?

    public var actualStart: Date?
    public var actualEnd: Date?
    /// Recorded active seconds, which may exclude pauses. Never inferred from wall time.
    public var actualDuration: TimeInterval?
    public var executionState: ExecutionState

    public var status: ActionStatus
    public let createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        title: String,
        notes: String? = nil,
        goalID: UUID? = nil,
        projectID: UUID? = nil,
        plannedStart: Date? = nil,
        plannedDuration: TimeInterval? = nil,
        actualStart: Date? = nil,
        actualEnd: Date? = nil,
        actualDuration: TimeInterval? = nil,
        executionState: ExecutionState = .notStarted,
        status: ActionStatus = .inbox,
        createdAt: Date = Date(),
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.goalID = goalID
        self.projectID = projectID
        self.plannedStart = plannedStart
        self.plannedDuration = plannedDuration
        self.actualStart = actualStart
        self.actualEnd = actualEnd
        self.actualDuration = actualDuration
        self.executionState = executionState
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
    }

    /// Call before committing or aggregating data. Does not mutate or discard draft values.
    /// Supply the referenced project to check consistency; missing links are permitted.
    public func validationIssues(project: Project? = nil) -> [ActionValidationIssue] {
        var issues: [ActionValidationIssue] = []
        if let duration = plannedDuration, !duration.isFinite || duration < 0 {
            issues.append(.invalidPlannedDuration)
        }
        if let duration = actualDuration, !duration.isFinite || duration < 0 {
            issues.append(.invalidActualDuration)
        }
        if let start = actualStart, let end = actualEnd, end < start {
            issues.append(.actualEndBeforeStart)
        }
        if let project = project, let projectID = projectID {
            if project.id != projectID {
                issues.append(.projectIDMismatch)
            } else if let goalID = goalID, let projectGoalID = project.goalID,
                      goalID != projectGoalID {
                issues.append(.goalIDMismatch)
            }
        }
        return issues
    }
}
