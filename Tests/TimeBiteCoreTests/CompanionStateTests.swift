import XCTest
import TimeBiteCore
import TimeBiteData
@testable import TimeBiteUI

final class CompanionStateTests: XCTestCase {
    func testProjectionClipsPeriodsAndDoesNotDoubleCountSources() throws {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let start = calendar.startOfDay(for: Date())
        let day = DateInterval(start: start, duration: 86400)
        let entries = [
            TodayActivityEntry(id: "health:private", title: "Private sample", source: .health, startDate: start, endDate: start.addingTimeInterval(7200), duration: 7200),
            TodayActivityEntry(id: "calendar:private", title: "Private event", source: .calendar, startDate: start.addingTimeInterval(3600), endDate: start.addingTimeInterval(10800), duration: 7200)
        ]
        let state = CompanionState(summary: TodayActivitySummary(dayInterval: day, entries: entries), actions: [], sessions: [], at: start.addingTimeInterval(10800), calendar: calendar)
        XCTAssertEqual(state.periods[0].capturedSeconds, 10800)
        XCTAssertEqual(state.periods[0].healthSeconds, 7200)
        XCTAssertEqual(state.periods[0].calendarSeconds, 7200)
        XCTAssertEqual(state.periods[1].capturedSeconds, 0)
        XCTAssertEqual(state.periods[2].capturedSeconds, 10800)
        let data = try CompanionState.encoder().encode(state)
        XCTAssertFalse(String(decoding: data, as: UTF8.self).contains("Private"))
        XCTAssertEqual(try CompanionState.decoder().decode(CompanionState.self, from: data), state)
        XCTAssertTrue(state.isStale(at: state.asOf.addingTimeInterval(121)))
    }

    @MainActor
    func testCompanionCommandsAreIdempotentAndRejectStaleSession() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "CompanionTests.\(UUID())"))
        let store = LocalActivityStore(defaults: defaults)
        _ = try store.createAction(title: "Real action", targetDuration: 1800)
        let controller = ActivityLoopController(store: store)
        let action = try XCTUnwrap(controller.companionState().actions.first)
        let start = CompanionCommand(type: "start", action: action)
        try controller.handleCompanionCommand(start)
        try controller.handleCompanionCommand(start)
        XCTAssertEqual(controller.snapshot.sessions.count, 1)
        let active = try XCTUnwrap(controller.companionState().active)
        let stalePause = CompanionCommand(type: "pause", action: active)
        controller.pause()
        XCTAssertThrowsError(try controller.handleCompanionCommand(stalePause))
        let paused = try XCTUnwrap(controller.companionState().active)
        let complete = CompanionCommand(type: "complete", action: paused)
        try controller.handleCompanionCommand(complete)
        try controller.handleCompanionCommand(complete)
        XCTAssertNil(controller.currentSession)
        XCTAssertEqual(controller.snapshot.sessions.count, 1)
    }
}
