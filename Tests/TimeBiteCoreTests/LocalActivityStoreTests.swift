import Foundation
import XCTest
import TimeBiteCore
import TimeBiteData

final class LocalActivityStoreTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_789_027_200)

    func testCreatePauseResumeCompleteAndRelaunch() throws {
        let suite = "timebite.test.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let first = LocalActivityStore(defaults: defaults)
        let action = try first.createAction(title: " Walk ", targetDuration: 60, at: start)
        let session = try first.start(actionID: action.id, at: start)
        try first.pause(sessionID: session.id, at: start.addingTimeInterval(10))
        try first.resume(sessionID: session.id, at: start.addingTimeInterval(100))

        let relaunched = LocalActivityStore(defaults: defaults)
        let running = try XCTUnwrap(relaunched.snapshot().sessions.first)
        XCTAssertEqual(running.id, session.id)
        XCTAssertEqual(running.elapsed(at: start.addingTimeInterval(120)), 30)
        XCTAssertTrue(try relaunched.complete(sessionID: session.id, at: start.addingTimeInterval(120)))
        XCTAssertFalse(try relaunched.complete(sessionID: session.id, at: start.addingTimeInterval(200)))
        let saved = try relaunched.snapshot()
        XCTAssertEqual(saved.actions.first?.actualDuration, 30)
        XCTAssertEqual(saved.actions.first?.executionState, .completed)
        XCTAssertEqual(saved.sessions.first?.revision, 3)
    }

    func testOneActiveSessionAcrossActions() throws {
        let suite = "timebite.test.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = LocalActivityStore(defaults: defaults)
        let first = try store.createAction(title: "A", targetDuration: 60, at: start)
        let second = try store.createAction(title: "B", targetDuration: 60, at: start)
        let active = try store.start(actionID: first.id, at: start)
        XCTAssertThrowsError(try store.start(actionID: second.id, at: start)) { error in
            XCTAssertEqual(error as? ActivityStoreError, .duplicateActiveSession)
        }
        XCTAssertEqual(try store.snapshot().sessions.count, 1)
        try store.complete(sessionID: active.id, at: start.addingTimeInterval(10))
        XCTAssertNoThrow(try store.start(actionID: second.id, at: start.addingTimeInterval(20)))
    }
}
