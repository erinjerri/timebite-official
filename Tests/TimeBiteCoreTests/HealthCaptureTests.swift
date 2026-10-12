import XCTest
import TimeBiteCore
import TimeBiteData
import TimeBiteHealth
@testable import TimeBiteUI

final class HealthCaptureTests: XCTestCase {
    @MainActor
    func testHealthRefreshFillsTodayWithSleepAndWorkoutHours() async throws {
        let now = Date()
        let day = try XCTUnwrap(Calendar.current.dateInterval(of: .day, for: now))
        let records = [
            HealthActivityRecord(externalIdentifier: "sleep", type: .sleep, title: "Sleep",
                startDate: day.start, endDate: day.start.addingTimeInterval(7 * 3600)),
            HealthActivityRecord(externalIdentifier: "workout", type: .workout, title: "Workout",
                startDate: day.start.addingTimeInterval(8 * 3600), endDate: day.start.addingTimeInterval(9 * 3600))
        ]
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "HealthCaptureTests.\(UUID())"))
        let controller = ActivityLoopController(store: LocalActivityStore(defaults: defaults),
            healthProvider: StubHealthProvider(records: records))
        await controller.refreshHealth()
        let summary = controller.todaySummary(at: now)
        XCTAssertEqual(controller.healthRecords.count, 2)
        XCTAssertEqual(summary.trackedDuration, 8 * 3600, accuracy: 0.001)
        XCTAssertEqual(summary.trackedDayProgress, 8 * 3600 / day.duration, accuracy: 0.001)
        guard case .loaded = controller.healthState else { return XCTFail("Expected completed Health fetch") }
    }

    @MainActor
    func testEmptyHealthFetchDoesNotInventCapturedHours() async throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "HealthCaptureTests.\(UUID())"))
        let controller = ActivityLoopController(store: LocalActivityStore(defaults: defaults),
            healthProvider: StubHealthProvider(records: []))
        await controller.refreshHealth()
        XCTAssertTrue(controller.healthRecords.isEmpty)
        XCTAssertEqual(controller.todaySummary().trackedDuration, 0)
        guard case .loaded = controller.healthState else { return XCTFail("Empty data is a completed fetch, not proof of read authorization") }
    }

    @MainActor
    func testOverlappingHealthRecordsAreCountedOnce() async throws {
        let now = Date()
        let start = Calendar.current.startOfDay(for: now)
        let records = [
            HealthActivityRecord(externalIdentifier: "a", type: .workout, title: "Workout",
                startDate: start, endDate: start.addingTimeInterval(3600)),
            HealthActivityRecord(externalIdentifier: "b", type: .mindfulness, title: "Mindfulness",
                startDate: start.addingTimeInterval(1800), endDate: start.addingTimeInterval(5400))
        ]
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "HealthCaptureTests.\(UUID())"))
        let controller = ActivityLoopController(store: LocalActivityStore(defaults: defaults),
            healthProvider: StubHealthProvider(records: records))
        await controller.refreshHealth()
        XCTAssertEqual(controller.todaySummary(at: now).trackedDuration, 5400, accuracy: 0.001)
    }
}

private struct StubHealthProvider: HealthActivityProvider {
    let records: [HealthActivityRecord]
    var isAvailable: Bool { true }
    func requestAuthorization() async throws {}
    func fetchActivity(for interval: DateInterval) async throws -> [HealthActivityRecord] { records }
}
