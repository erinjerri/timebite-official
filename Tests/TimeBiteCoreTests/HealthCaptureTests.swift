import XCTest
import TimeBiteCore
import TimeBiteData
import TimeBiteHealth
@testable import TimeBiteUI

final class HealthCaptureTests: XCTestCase {
    func testCategorySegmentsCountOverlapOnceAndUseLinkedGoal() {
        let start = Calendar.current.startOfDay(for: Date())
        let day = DateInterval(start: start, end: start.addingTimeInterval(86400))
        var goal = Goal(title: "Family time"); goal.lifeArea = "Family"
        let action = Action(title: "Call", goalID: goal.id)
        var snapshot = ActivitySnapshot(); snapshot.goals = [goal]; snapshot.actions = [action]
        let entries = [
            TodayActivityEntry(id: "timebite:\(action.id.uuidString)", title: "Call", source: .timeBite, startDate: start, endDate: start.addingTimeInterval(3600), duration: 3600),
            TodayActivityEntry(id: "health:test", title: "Mindfulness", source: .health, startDate: start.addingTimeInterval(1800), endDate: start.addingTimeInterval(5400), duration: 3600)
        ]
        let ring = TrackedDayRingView(summary: TodayActivitySummary(dayInterval: day, entries: entries), snapshot: snapshot, now: start)
        let slices = ring.slices(day)
        XCTAssertEqual(slices.map { $0.0 }, ["Family", "Fitness/Health"])
        XCTAssertEqual(slices.map { $0.1 }, [3600, 1800])
    }

    func testGoalClassificationPersistsAndLegacyGoalsDecode() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "GoalClassificationTests.\(UUID())"))
        let store = LocalActivityStore(defaults: defaults)
        var goal = Goal(title: "Build fitness")
        goal.lifeArea = "Fitness/Health"; goal.goalType = "Long Term"; goal.focus = "Health"
        try store.saveGoal(goal)
        let saved = try XCTUnwrap(store.snapshot().goals.first)
        XCTAssertEqual(saved.lifeArea, "Fitness/Health")
        XCTAssertEqual(saved.goalType, "Long Term")
        XCTAssertEqual(saved.focus, "Health")
        let encoded = try JSONEncoder().encode(goal)
        var legacy = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        for key in ["lifeArea", "goalType", "focus"] { legacy.removeValue(forKey: key) }
        let decoded = try JSONDecoder().decode(Goal.self, from: JSONSerialization.data(withJSONObject: legacy))
        XCTAssertNil(decoded.lifeArea)
        XCTAssertEqual(decoded.title, goal.title)
    }

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
