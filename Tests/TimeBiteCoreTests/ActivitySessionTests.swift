import Foundation
import XCTest
import TimeBiteCore

final class ActivitySessionTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_789_027_200)

    private func session(target: TimeInterval = 60) throws -> ActivitySession {
        try ActivitySession(actionID: UUID(), startedAt: start, targetDuration: target)
    }

    func testRunningElapsedUsesClockRatherThanTickCount() throws {
        let value = try session()
        XCTAssertEqual(value.elapsed(at: start.addingTimeInterval(30)), 30)
        XCTAssertEqual(value.elapsed(at: start.addingTimeInterval(3_600)), 3_600)
        XCTAssertEqual(value.ringProgress(at: start.addingTimeInterval(30)), 0.5)
    }

    func testPauseFreezesElapsedAndResumeAddsOnlyActiveTime() throws {
        var value = try session()
        try value.pause(at: start.addingTimeInterval(20))
        XCTAssertEqual(value.elapsed(at: start.addingTimeInterval(1_000)), 20)
        XCTAssertEqual(value.status, .paused)
        try value.resume(at: start.addingTimeInterval(1_000))
        XCTAssertEqual(value.elapsed(at: start.addingTimeInterval(1_010)), 30)
        XCTAssertEqual(value.revision, 2)
    }

    func testCompletionFromRunningAndPausedIsIdempotent() throws {
        var running = try session()
        XCTAssertTrue(try running.complete(at: start.addingTimeInterval(10)))
        XCTAssertFalse(try running.complete(at: start.addingTimeInterval(100)))
        XCTAssertEqual(running.elapsed(at: start.addingTimeInterval(100)), 10)
        XCTAssertEqual(running.ringProgress(at: start.addingTimeInterval(100)), 1)
        XCTAssertEqual(running.revision, 1)

        var paused = try session()
        try paused.pause(at: start.addingTimeInterval(15))
        XCTAssertTrue(try paused.complete(at: start.addingTimeInterval(100)))
        XCTAssertEqual(paused.elapsed(at: start.addingTimeInterval(200)), 15)
    }

    func testEncodedSessionReconstructsAfterRelaunch() throws {
        var value = try session()
        try value.pause(at: start.addingTimeInterval(10))
        try value.resume(at: start.addingTimeInterval(100))
        let restored = try JSONDecoder().decode(ActivitySession.self, from: JSONEncoder().encode(value))
        XCTAssertEqual(restored.id, value.id)
        XCTAssertEqual(restored.elapsed(at: start.addingTimeInterval(125)), 35)
        XCTAssertEqual(restored.activeIntervals.count, 1)
    }

    func testInvalidTransitionsAndClockRollbackDoNotMutateSession() throws {
        var value = try session()
        let original = value
        XCTAssertThrowsError(try value.pause(at: start.addingTimeInterval(-1)))
        XCTAssertEqual(value, original)
        XCTAssertThrowsError(try value.resume(at: start))
        try value.pause(at: start.addingTimeInterval(10))
        XCTAssertThrowsError(try value.pause(at: start.addingTimeInterval(20)))
        XCTAssertThrowsError(try value.resume(at: start.addingTimeInterval(5)))
    }

    func testTargetValidationAndProgressClamping() throws {
        for invalid in [0.0, -1.0, Double.infinity, Double.nan] {
            XCTAssertThrowsError(try session(target: invalid))
        }
        let value = try session()
        XCTAssertEqual(value.ringProgress(at: start.addingTimeInterval(-10)), 0)
        XCTAssertEqual(value.ringProgress(at: start.addingTimeInterval(120)), 1)
    }

    func testActiveDurationSplitsAtCalendarBoundary() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let midnight = calendar.startOfDay(for: start).addingTimeInterval(86_400)
        var value = try ActivitySession(actionID: UUID(), startedAt: midnight.addingTimeInterval(-10), targetDuration: 60)
        try value.complete(at: midnight.addingTimeInterval(20))
        let yesterday = DateInterval(start: midnight.addingTimeInterval(-86_400), end: midnight)
        let today = DateInterval(start: midnight, end: midnight.addingTimeInterval(86_400))
        XCTAssertEqual(value.activeDuration(in: yesterday, at: midnight), 10)
        XCTAssertEqual(value.activeDuration(in: today, at: midnight), 20)
    }

    func testDailyProgressMultipleSessionsAndDuplicateCompletion() throws {
        let actionA = Action(title: "A", plannedDuration: 60, createdAt: start)
        let actionB = Action(title: "B", plannedDuration: 60, createdAt: start)
        var first = try ActivitySession(actionID: actionA.id, startedAt: start, targetDuration: 60)
        var duplicate = try ActivitySession(actionID: actionA.id, startedAt: start.addingTimeInterval(20), targetDuration: 60)
        var second = try ActivitySession(actionID: actionB.id, startedAt: start.addingTimeInterval(30), targetDuration: 60)
        try first.complete(at: start.addingTimeInterval(20))
        try duplicate.complete(at: start.addingTimeInterval(30))
        try second.complete(at: start.addingTimeInterval(40))
        let result = DailyProgress.calculate(actions: [actionA, actionB], sessions: [first, duplicate, second], at: start.addingTimeInterval(50))
        XCTAssertEqual(result.completedActions, 2)
        XCTAssertEqual(result.plannedDuration, 120)
        XCTAssertEqual(result.executedDuration, 40)
        XCTAssertEqual(result.ringProgress, 1)
    }

    func testDailyResetExcludesYesterdayCompletions() throws {
        let action = Action(title: "Yesterday", plannedDuration: 60, createdAt: start)
        var value = try ActivitySession(actionID: action.id, startedAt: start, targetDuration: 60)
        try value.complete(at: start.addingTimeInterval(10))
        let tomorrow = start.addingTimeInterval(86_400)
        let result = DailyProgress.calculate(actions: [action], sessions: [value], at: tomorrow)
        XCTAssertEqual(result.completedActions, 0)
        XCTAssertEqual(result.plannedDuration, 0)
        XCTAssertEqual(result.ringProgress, 0)
    }

    func testCompletedActionCreditsTargetWhileAnotherRuns() throws {
        let done = Action(title: "Done", plannedDuration: 60, createdAt: start)
        let running = Action(title: "Running", plannedDuration: 60, createdAt: start)
        var completed = try ActivitySession(actionID: done.id, startedAt: start, targetDuration: 60)
        try completed.complete(at: start.addingTimeInterval(10))
        let active = try ActivitySession(actionID: running.id, startedAt: start, targetDuration: 60)
        let result = DailyProgress.calculate(actions: [done, running], sessions: [completed, active], at: start.addingTimeInterval(20))
        XCTAssertEqual(result.executedDuration, 30)
        XCTAssertEqual(result.creditedDuration, 80)
        XCTAssertEqual(result.ringProgress, 80.0 / 120.0)
    }
}
