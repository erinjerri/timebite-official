import Foundation
import XCTest
import TimeBiteCore
import TimeBiteData
import TimeBiteSync

final class SessionReconcilerTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_789_027_200)

    func testCompletionWinsOverStaleRunningState() throws {
        let running = try ActivitySession(actionID: UUID(), startedAt: start, targetDuration: 60)
        var completed = running
        try completed.complete(at: start.addingTimeInterval(10))
        XCTAssertEqual(SessionReconciler.choose(completed, running), completed)
        XCTAssertEqual(SessionReconciler.choose(running, completed), completed)
    }

    func testHigherRevisionWinsAndDoesNotResetElapsed() throws {
        let original = try ActivitySession(actionID: UUID(), startedAt: start, targetDuration: 60)
        var resumed = original
        try resumed.pause(at: start.addingTimeInterval(10))
        try resumed.resume(at: start.addingTimeInterval(100))
        let merged = SessionReconciler.choose(original, resumed)
        XCTAssertEqual(merged.id, original.id)
        XCTAssertEqual(merged.elapsed(at: start.addingTimeInterval(110)), 20)
    }

    func testMergeDeduplicatesSessionAndRejectsCompetingActiveIDs() throws {
        let action = Action(title: "A", plannedDuration: 60, createdAt: start)
        let session = try ActivitySession(actionID: action.id, startedAt: start, targetDuration: 60)
        var left = ActivitySnapshot()
        left.actions = [action]
        left.sessions = [session]
        var right = left
        let merged = try SessionReconciler.merge(left, right)
        XCTAssertEqual(merged.sessions.count, 1)
        right.sessions = [try ActivitySession(actionID: action.id,
                                              startedAt: start.addingTimeInterval(5),
                                              targetDuration: 60)]
        XCTAssertThrowsError(try SessionReconciler.merge(left, right)) { error in
            XCTAssertEqual(error as? SessionReconciliationError, .competingActiveSessions)
        }
    }

    func testTerminalSessionAlsoWinsOverStaleActionStatus() throws {
        let action = Action(title: "A", plannedDuration: 60, createdAt: start)
        let running = try ActivitySession(actionID: action.id, startedAt: start, targetDuration: 60)
        var completed = running
        try completed.complete(at: start.addingTimeInterval(10))
        var left = ActivitySnapshot()
        left.actions = [action]
        left.sessions = [running]
        var right = ActivitySnapshot()
        right.actions = [action]
        right.sessions = [completed]
        let merged = try SessionReconciler.merge(left, right)
        XCTAssertEqual(merged.actions.first?.executionState, .completed)
        XCTAssertEqual(merged.actions.first?.actualDuration, 10)
        XCTAssertEqual(merged.sessions.first?.status, .completed)
    }
}
