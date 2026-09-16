import Foundation
import XCTest
import TimeBiteCore

final class TimeBiteCoreTests: XCTestCase {
    private let timestamp = Date(timeIntervalSince1970: 1_789_027_200)

    private func fixture(_ name: String) throws -> Data {
        let url = try XCTUnwrap(Bundle.module.url(
            forResource: name, withExtension: "json", subdirectory: "Fixtures"
        ))
        return try Data(contentsOf: url)
    }

    private func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    private func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        return encoder
    }

    func testStandaloneActionCreation() {
        let action = Action(title: "Leg workout", createdAt: timestamp)
        XCTAssertEqual(action.title, "Leg workout")
        XCTAssertNil(action.goalID)
        XCTAssertNil(action.projectID)
        XCTAssertEqual(action.status, .inbox)
        XCTAssertEqual(action.executionState, .notStarted)
        XCTAssertEqual(action.updatedAt, action.createdAt)
        XCTAssertTrue(action.validationIssues().isEmpty)
    }

    func testProjectWithoutGoal() {
        let project = Project(title: "Apple TestFlight", createdAt: timestamp)
        XCTAssertNil(project.goalID)
        XCTAssertEqual(project.status, .active)
        XCTAssertEqual(project.createdAt, project.updatedAt)
    }

    func testActionLinkedDirectlyToGoal() {
        let goal = Goal(title: "Improve fitness")
        let action = Action(title: "Leg workout", goalID: goal.id)
        XCTAssertEqual(action.goalID, goal.id)
        XCTAssertNil(action.projectID)
    }

    func testActionLinkedToProject() {
        let project = Project(title: "Apple TestFlight")
        let action = Action(title: "Fix AM/PM ring rendering", projectID: project.id)
        XCTAssertEqual(action.projectID, project.id)
        XCTAssertNil(action.goalID)
        XCTAssertTrue(action.validationIssues(project: project).isEmpty)
    }

    func testActionLinkedToBothProjectAndGoal() {
        let goal = Goal(title: "Launch TimeBite Beta")
        let project = Project(title: "Apple TestFlight", goalID: goal.id)
        let action = Action(title: "Fix AM/PM ring rendering", goalID: goal.id, projectID: project.id)
        XCTAssertEqual(action.goalID, goal.id)
        XCTAssertEqual(action.projectID, project.id)
        XCTAssertTrue(action.validationIssues(project: project).isEmpty)
    }

    func testRelationshipValidationAllowsIncompleteEditsAndReportsConflicts() {
        var project = Project(title: "Beta", goalID: UUID())
        var action = Action(title: "Fix rings", goalID: UUID(), projectID: project.id)
        XCTAssertEqual(action.validationIssues(project: project), [.goalIDMismatch])
        action.goalID = nil
        XCTAssertTrue(action.validationIssues(project: project).isEmpty)
        action.goalID = UUID()
        project.goalID = nil
        XCTAssertTrue(action.validationIssues(project: project).isEmpty)
        action.projectID = nil
        XCTAssertTrue(action.validationIssues(project: project).isEmpty)
        action.projectID = UUID()
        XCTAssertEqual(action.validationIssues(project: project), [.projectIDMismatch])
        XCTAssertTrue(action.validationIssues().isEmpty)
    }

    func testAllFieldsRoundTrip() throws {
        let goal = Goal(title: "Fitness", notes: "Long-term", targetDate: timestamp,
                        status: .completed, createdAt: timestamp, updatedAt: timestamp)
        let project = Project(title: "Strength", notes: "Weekly", goalID: goal.id,
                              startDate: timestamp, targetDate: timestamp, status: .cancelled,
                              createdAt: timestamp, updatedAt: timestamp)
        let action = Action(title: "Workout", notes: "Leg day", goalID: goal.id,
                            projectID: project.id, plannedStart: timestamp, plannedDuration: 3600,
                            actualStart: timestamp, actualEnd: timestamp.addingTimeInterval(3600),
                            actualDuration: 3000, executionState: .completed, status: .completed,
                            createdAt: timestamp, updatedAt: timestamp.addingTimeInterval(3600))
        XCTAssertEqual(try decoder().decode(Goal.self, from: encoder().encode(goal)), goal)
        XCTAssertEqual(try decoder().decode(Project.self, from: encoder().encode(project)), project)
        XCTAssertEqual(try decoder().decode(Action.self, from: encoder().encode(action)), action)
    }

    func testOptionalFieldsAreAbsentOrNull() throws {
        let data = try fixture("standalone-action")
        let action = try decoder().decode(Action.self, from: data)
        XCTAssertNil(action.notes)
        XCTAssertNil(action.plannedStart)
        XCTAssertNil(action.plannedDuration)
        XCTAssertNil(action.actualStart)
        XCTAssertNil(action.actualEnd)
        XCTAssertNil(action.actualDuration)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        for key in ["notes", "goalID", "projectID", "plannedStart", "plannedDuration",
                    "actualStart", "actualEnd", "actualDuration"] {
            json[key] = NSNull()
        }
        XCTAssertEqual(try decoder().decode(Action.self, from: JSONSerialization.data(withJSONObject: json)), action)
        let project = Project(title: "Group")
        XCTAssertNil(project.notes)
        XCTAssertNil(project.startDate)
        XCTAssertNil(project.targetDate)
        let goal = Goal(title: "Outcome")
        XCTAssertNil(goal.notes)
        XCTAssertNil(goal.targetDate)
    }

    func testCompletedTimingPreservesActiveDurationExcludingPauses() throws {
        let action = try decoder().decode(Action.self, from: fixture("completed-action"))
        XCTAssertEqual(action.status, .completed)
        XCTAssertEqual(action.executionState, .completed)
        XCTAssertEqual(action.actualDuration, 3000)
        let start = try XCTUnwrap(action.actualStart)
        let end = try XCTUnwrap(action.actualEnd)
        XCTAssertEqual(end.timeIntervalSince(start), 3600)
        XCTAssertTrue(action.validationIssues().isEmpty)
    }

    func testInvalidDurationHandlingAfterCreationAndEditing() {
        for invalid in [-1.0, Double.infinity, -Double.infinity, Double.nan] {
            var action = Action(title: "Draft", plannedDuration: invalid)
            action.actualDuration = invalid
            XCTAssertEqual(action.validationIssues(), [.invalidPlannedDuration, .invalidActualDuration])
        }
        for valid in [0.0, 0.5, 3600.0] {
            XCTAssertTrue(Action(title: "Draft", plannedDuration: valid, actualDuration: valid)
                .validationIssues().isEmpty)
        }
        XCTAssertTrue(Action(title: "Draft").validationIssues().isEmpty)
    }

    func testImportedNegativeDurationIsReportedWithoutDiscardingDraft() throws {
        var action = try decoder().decode(Action.self, from: fixture("standalone-action"))
        action.actualDuration = -10
        let imported = try decoder().decode(Action.self, from: encoder().encode(action))
        XCTAssertEqual(imported.actualDuration, -10)
        XCTAssertEqual(imported.validationIssues(), [.invalidActualDuration])
        action.actualDuration = .infinity
        XCTAssertThrowsError(try encoder().encode(action))
    }

    func testReversedTimingIsReportedAndPartialTimingIsAllowed() {
        var action = Action(title: "Draft", actualStart: timestamp,
                            actualEnd: timestamp.addingTimeInterval(-1))
        XCTAssertEqual(action.validationIssues(), [.actualEndBeforeStart])
        action.actualEnd = timestamp
        XCTAssertTrue(action.validationIssues().isEmpty)
        action.actualStart = nil
        XCTAssertTrue(action.validationIssues().isEmpty)
    }

    func testEqualityAndStableIdentity() {
        let action = Action(title: "Workout")
        var edited = action
        XCTAssertEqual(edited, action)
        edited.title = "Leg workout"
        XCTAssertEqual(edited.id, action.id)
        XCTAssertNotEqual(edited, action)
        XCTAssertNotEqual(Action(title: "Workout").id, action.id)
        let goal = Goal(title: "Fitness")
        var editedGoal = goal
        editedGoal.status = .completed
        XCTAssertEqual(editedGoal.id, goal.id)
        XCTAssertNotEqual(editedGoal, goal)
        let project = Project(title: "Strength")
        var editedProject = project
        editedProject.notes = "Updated"
        XCTAssertEqual(editedProject.id, project.id)
        XCTAssertNotEqual(editedProject, project)
    }

    func testEveryFixtureRoundTripsDeterministically() throws {
        for name in ["standalone-action", "project-action", "goal-action", "completed-action"] {
            let original = try fixture(name)
            let action = try decoder().decode(Action.self, from: original)
            let encoded = try encoder().encode(action)
            XCTAssertEqual(try decoder().decode(Action.self, from: encoded), action)
            XCTAssertEqual(try encoder().encode(action), encoded)
            XCTAssertEqual(try JSONSerialization.jsonObject(with: original) as? NSDictionary,
                           try JSONSerialization.jsonObject(with: encoded) as? NSDictionary)
        }
        struct Hierarchy: Codable, Equatable {
            var goals: [Goal]
            var projects: [Project]
            var actions: [Action]
        }
        let hierarchy = try decoder().decode(Hierarchy.self, from: fixture("full-hierarchy"))
        XCTAssertEqual(try decoder().decode(Hierarchy.self, from: encoder().encode(hierarchy)), hierarchy)
        let goal = try XCTUnwrap(hierarchy.goals.first)
        let project = try XCTUnwrap(hierarchy.projects.first)
        let action = try XCTUnwrap(hierarchy.actions.first)
        XCTAssertEqual(project.goalID, goal.id)
        XCTAssertEqual(action.goalID, goal.id)
        XCTAssertEqual(action.projectID, project.id)
        XCTAssertTrue(action.validationIssues(project: project).isEmpty)
    }
}
