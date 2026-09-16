import Foundation
import TimeBiteCore

public enum ActivityStoreError: Error, Equatable {
    case duplicateActiveSession
    case actionNotFound
    case sessionNotFound
    case unsupportedSchema
}

public struct ActivitySnapshot: Codable, Equatable, Sendable {
    public var schemaVersion = 1
    public var actions: [Action] = []
    public var sessions: [ActivitySession] = []

    public init() {}
}

/// Local release storage. Its key is deliberately distinct from the legacy
/// Mac planning key until an explicit data migration is designed and tested.
public final class LocalActivityStore {
    private static let key = "timebite.activityStore.v1"
    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func snapshot() throws -> ActivitySnapshot {
        guard let data = defaults.data(forKey: Self.key) else { return ActivitySnapshot() }
        let value = try decoder.decode(ActivitySnapshot.self, from: data)
        guard value.schemaVersion == 1 else { throw ActivityStoreError.unsupportedSchema }
        return value
    }

    @discardableResult
    public func createAction(title: String, targetDuration: TimeInterval, at date: Date = Date()) throws -> Action {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, targetDuration.isFinite, targetDuration > 0 else {
            throw ActivitySessionError.invalidTargetDuration
        }
        let action = Action(title: trimmed, plannedDuration: targetDuration,
                            status: .planned, createdAt: date)
        try update { $0.actions.append(action) }
        return action
    }

    @discardableResult
    public func start(actionID: UUID, at date: Date = Date()) throws -> ActivitySession {
        var result: ActivitySession?
        try update { state in
            guard let index = state.actions.firstIndex(where: { $0.id == actionID }) else {
                throw ActivityStoreError.actionNotFound
            }
            guard !state.sessions.contains(where: { $0.status != .completed }) else {
                throw ActivityStoreError.duplicateActiveSession
            }
            let action = state.actions[index]
            result = try ActivitySession(actionID: actionID, startedAt: date,
                                         targetDuration: action.plannedDuration ?? 0)
            state.sessions.append(result!)
            state.actions[index].executionState = .running
            state.actions[index].status = .active
            state.actions[index].updatedAt = date
        }
        return result!
    }

    public func pause(sessionID: UUID, at date: Date = Date()) throws {
        try transition(sessionID: sessionID, at: date) { state, index in
            try state.sessions[index].pause(at: date)
            if let actionIndex = state.actions.firstIndex(where: { $0.id == state.sessions[index].actionID }) {
                state.actions[actionIndex].executionState = .paused
                state.actions[actionIndex].updatedAt = date
            }
        }
    }

    public func resume(sessionID: UUID, at date: Date = Date()) throws {
        try transition(sessionID: sessionID, at: date) { state, index in
            try state.sessions[index].resume(at: date)
            if let actionIndex = state.actions.firstIndex(where: { $0.id == state.sessions[index].actionID }) {
                state.actions[actionIndex].executionState = .running
                state.actions[actionIndex].updatedAt = date
            }
        }
    }

    @discardableResult
    public func complete(sessionID: UUID, at date: Date = Date()) throws -> Bool {
        var changed = false
        try transition(sessionID: sessionID, at: date) { state, index in
            changed = try state.sessions[index].complete(at: date)
            guard changed else { return }
            if let actionIndex = state.actions.firstIndex(where: { $0.id == state.sessions[index].actionID }) {
                state.actions[actionIndex].executionState = .completed
                state.actions[actionIndex].status = .completed
                state.actions[actionIndex].actualStart = state.sessions[index].startedAt
                state.actions[actionIndex].actualEnd = date
                state.actions[actionIndex].actualDuration = state.sessions[index].accumulatedDuration
                state.actions[actionIndex].updatedAt = date
            }
        }
        return changed
    }

    private func transition(
        sessionID: UUID, at date: Date,
        change: (inout ActivitySnapshot, Int) throws -> Void
    ) throws {
        try update { state in
            guard let index = state.sessions.firstIndex(where: { $0.id == sessionID }) else {
                throw ActivityStoreError.sessionNotFound
            }
            try change(&state, index)
        }
    }

    private func update(_ change: (inout ActivitySnapshot) throws -> Void) throws {
        var value = try snapshot()
        try change(&value)
        defaults.set(try encoder.encode(value), forKey: Self.key)
    }
}
