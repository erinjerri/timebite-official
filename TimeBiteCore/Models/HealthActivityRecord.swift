import Foundation

public enum HealthActivityType: String, Codable, Equatable, Sendable {
    case sleep
    case workout
    case mindfulness
}

public struct HealthActivityRecord: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let externalIdentifier: String
    public let type: HealthActivityType
    public let title: String
    public let startDate: Date
    public let endDate: Date
    public let duration: TimeInterval
    public let source: String

    public init(
        id: UUID = UUID(),
        externalIdentifier: String,
        type: HealthActivityType,
        title: String,
        startDate: Date,
        endDate: Date,
        source: String = "Health"
    ) {
        self.id = id
        self.externalIdentifier = externalIdentifier
        self.type = type
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.duration = max(0, endDate.timeIntervalSince(startDate))
        self.source = source
    }
}

