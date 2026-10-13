import Foundation
import TimeBiteCore

public enum CompanionControlError: LocalizedError {
    case unavailable, stale, invalid
    public var errorDescription: String? {
        switch self {
        case .unavailable: return "Open TimeBite on iPhone to use controls."
        case .stale: return "Action changed. Refresh before trying again."
        case .invalid: return "This action transition is unavailable."
        }
    }
}

extension ActivityLoopController {
    public func companionState(at date: Date = Date()) -> CompanionState {
        CompanionState(summary: todaySummary(at: date), actions: snapshot.actions, sessions: snapshot.sessions, at: date)
    }
    public func handleCompanionCommand(_ command: CompanionCommand) throws {
        let defaults = UserDefaults.standard
        var applied = defaults.stringArray(forKey: "timebite.companion.applied") ?? []
        if applied.contains(command.id.uuidString) { return }
        guard let action = snapshot.actions.first(where: { $0.id == command.actionID }) else { throw CompanionControlError.stale }
        if command.type == "start" {
            guard command.sessionID == nil, currentSession == nil, action.executionState != .completed else { throw CompanionControlError.stale }
            start(action)
        } else {
            guard let session = currentSession, session.id == command.sessionID,
                  session.actionID == command.actionID, session.revision == command.revision else { throw CompanionControlError.stale }
            switch command.type {
            case "pause": guard session.status == .running else { throw CompanionControlError.invalid }; pause()
            case "resume": guard session.status == .paused else { throw CompanionControlError.invalid }; resume()
            case "complete": complete()
            default: throw CompanionControlError.invalid
            }
        }
        if let errorMessage { throw NSError(domain: "TimeBite", code: 1, userInfo: [NSLocalizedDescriptionKey: errorMessage]) }
        applied.append(command.id.uuidString)
        defaults.set(Array(applied.suffix(256)), forKey: "timebite.companion.applied")
    }
}
