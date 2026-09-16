import Foundation

public struct Project: TimeBiteItem {
    public let id: UUID
    public var title: String
    public var notes: String?
    public var goalID: UUID?
    public var startDate: Date?
    public var targetDate: Date?
    public var status: ItemStatus
    public let createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        title: String,
        notes: String? = nil,
        goalID: UUID? = nil,
        startDate: Date? = nil,
        targetDate: Date? = nil,
        status: ItemStatus = .active,
        createdAt: Date = Date(),
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.goalID = goalID
        self.startDate = startDate
        self.targetDate = targetDate
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
    }
}
