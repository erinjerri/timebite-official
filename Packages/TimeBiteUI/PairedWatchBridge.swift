#if os(iOS) || os(watchOS)
import Foundation
import WatchConnectivity
import Combine
import TimeBiteCore

/// iPhone is authoritative. Controls are immediate-only: no delayed offline replay.
final class PairedWatchBridge: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = PairedWatchBridge()
    @Published private(set) var state: CompanionState?
    @Published private(set) var status = "Connecting to paired device…"
    var stateProvider: (() -> CompanionState?)?
    var commandHandler: ((CompanionCommand) throws -> Void)?
    private override init() {
        super.init()
        if let data = UserDefaults.standard.data(forKey: "timebite.companion.watchState"), let decoded = try? CompanionState.decoder().decode(CompanionState.self, from: data) { state = decoded }
        guard WCSession.isSupported() else { status = "WatchConnectivity unavailable"; return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }
    func publish() {
        guard WCSession.default.activationState == .activated, let projection = stateProvider?() else { return }
        do {
            let data = try CompanionState.encoder().encode(projection)
            try WCSession.default.updateApplicationContext(["state": data])
            status = "Latest state queued for Watch"
        } catch { status = error.localizedDescription }
    }
    func requestRefresh() {
        guard WCSession.default.isReachable else { status = "Open TimeBite on the paired iPhone"; return }
        WCSession.default.sendMessage(["refresh": true], replyHandler: { reply in
            DispatchQueue.main.async { self.accept(reply) }
        }, errorHandler: { error in DispatchQueue.main.async { self.status = error.localizedDescription } })
    }
    func send(_ command: CompanionCommand) {
        guard WCSession.default.isReachable, state?.isStale() == false else { status = "Refresh from iPhone before sending controls"; return }
        do {
            let data = try CompanionState.encoder().encode(command)
            WCSession.default.sendMessage(["command": data], replyHandler: { reply in
                DispatchQueue.main.async { self.accept(reply) }
            }, errorHandler: { error in DispatchQueue.main.async { self.status = error.localizedDescription } })
        } catch { status = error.localizedDescription }
    }
    private func accept(_ context: [String: Any]) {
        if let error = context["error"] as? String { status = error; return }
        guard let data = context["state"] as? Data, let incoming = try? CompanionState.decoder().decode(CompanionState.self, from: data), incoming.version == 1 else { return }
        if let state, incoming.asOf < state.asOf { return }
        state = incoming
        UserDefaults.standard.set(data, forKey: "timebite.companion.watchState")
        status = "Updated from iPhone"
    }
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            if let error { self.status = error.localizedDescription }
            else { self.accept(session.receivedApplicationContext); self.publish() }
        }
    }
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        DispatchQueue.main.async { self.accept(applicationContext) }
    }
    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        DispatchQueue.main.async {
            do {
                if let data = message["command"] as? Data {
                    guard let handler = self.commandHandler else { throw CompanionControlError.unavailable }
                    try handler(CompanionState.decoder().decode(CompanionCommand.self, from: data))
                }
                guard let projection = self.stateProvider?() else { throw CompanionControlError.unavailable }
                replyHandler(["state": try CompanionState.encoder().encode(projection)])
                self.publish()
            } catch { replyHandler(["error": error.localizedDescription]) }
        }
    }
    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { session.activate() }
    #endif
}
#endif
