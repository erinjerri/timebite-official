import Foundation
import TimeBiteCore
import TimeBiteData

public enum SessionReconciliationError: Error, Equatable {
    case competingActiveSessions
}

/// Pure conflict policy for future transports. A completed session is terminal;
/// lower revisions cannot resurrect it. Equal revisions use event time.
public enum SessionReconciler {
    public static func choose(_ local: ActivitySession, _ incoming: ActivitySession) -> ActivitySession {
        precondition(local.id == incoming.id)
        if local.status == .completed && incoming.status != .completed { return local }
        if incoming.status == .completed && local.status != .completed { return incoming }
        if local.revision != incoming.revision {
            return local.revision > incoming.revision ? local : incoming
        }
        let localEvent = eventDate(local)
        let incomingEvent = eventDate(incoming)
        if localEvent != incomingEvent { return localEvent > incomingEvent ? local : incoming }
        return local
    }

    public static func merge(_ local: ActivitySnapshot, _ incoming: ActivitySnapshot) throws -> ActivitySnapshot {
        var result = local
        for action in incoming.actions {
            if let index = result.actions.firstIndex(where: { $0.id == action.id }) {
                if action.updatedAt > result.actions[index].updatedAt { result.actions[index] = action }
            } else {
                result.actions.append(action)
            }
        }
        for session in incoming.sessions {
            if let index = result.sessions.firstIndex(where: { $0.id == session.id }) {
                result.sessions[index] = choose(result.sessions[index], session)
            } else {
                result.sessions.append(session)
            }
        }
        guard result.sessions.filter({ $0.status != .completed }).count <= 1 else {
            throw SessionReconciliationError.competingActiveSessions
        }
        for session in result.sessions where session.status == .completed {
            guard let index = result.actions.firstIndex(where: { $0.id == session.actionID }),
                  let completedAt = session.completedAt else { continue }
            result.actions[index].executionState = .completed
            result.actions[index].status = .completed
            result.actions[index].actualStart = session.startedAt
            result.actions[index].actualEnd = completedAt
            result.actions[index].actualDuration = session.accumulatedDuration
            result.actions[index].updatedAt = max(result.actions[index].updatedAt, completedAt)
        }
        return result
    }

    private static func eventDate(_ session: ActivitySession) -> Date {
        session.completedAt ?? session.pausedAt ?? session.runningSince ?? session.startedAt
    }
}
