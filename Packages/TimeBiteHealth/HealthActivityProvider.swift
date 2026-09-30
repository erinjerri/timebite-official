import Foundation
import TimeBiteCore

public protocol HealthActivityProvider {
    var isAvailable: Bool { get }

    func requestAuthorization() async throws
    func fetchActivity(for interval: DateInterval) async throws -> [HealthActivityRecord]
}

public enum HealthActivityProviderError: Error, Equatable {
    case unavailable
    case unsupportedPlatform
    case healthDataTypeUnavailable
}

