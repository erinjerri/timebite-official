#if os(iOS) || os(macOS)
import SwiftUI
import TimeBiteCore

@MainActor
final class CompanionRelayClient: ObservableObject {
    @Published var endpoint = UserDefaults.standard.string(forKey: "timebite.relay.endpoint") ?? "http://localhost:8765"
    @Published var token = ""
    @Published var enabled = false
    @Published var state: CompanionState?
    @Published var status = "Disconnected"
    func request(_ path: String, method: String = "GET", body: Data? = nil) async throws -> Data {
        guard let base = URL(string: endpoint), ["https", "http"].contains(base.scheme), base.host != nil, !token.isEmpty else { throw CompanionControlError.unavailable }
        var request = URLRequest(url: base.appendingPathComponent(path))
        request.httpMethod = method; request.httpBody = body; request.timeoutInterval = 5
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse, (200...299).contains(response.statusCode) else {
            throw NSError(domain: "CompanionRelay", code: 1, userInfo: [NSLocalizedDescriptionKey: "Relay rejected request. Check token, connection, and iPhone freshness."])
        }
        return data
    }
    func tick(authority: ActivityLoopController?) async {
        guard enabled else { return }
        UserDefaults.standard.set(endpoint, forKey: "timebite.relay.endpoint")
        do {
            if let authority {
                let projection = authority.companionState()
                _ = try await request("state", method: "POST", body: CompanionState.encoder().encode(projection))
                let commands = try CompanionState.decoder().decode([CompanionCommand].self, from: await request("commands"))
                for command in commands {
                    var result: [String: String] = ["id": command.id.uuidString, "status": "applied"]
                    do { try authority.handleCompanionCommand(command) }
                    catch { result["status"] = "rejected"; result["error"] = error.localizedDescription }
                    _ = try await request("ack", method: "POST", body: JSONSerialization.data(withJSONObject: result))
                }
                state = authority.companionState()
                if !commands.isEmpty { _ = try await request("state", method: "POST", body: CompanionState.encoder().encode(state)) }
                status = "iPhone state published"
            } else {
                state = try CompanionState.decoder().decode(CompanionState.self, from: await request("state"))
                guard state?.version == 1 else { throw CompanionControlError.invalid }
                status = state?.isStale() == true ? "Stale · open iPhone" : "Updated from iPhone"
            }
        } catch { status = error.localizedDescription }
    }
    func send(_ command: CompanionCommand) async {
        guard state?.isStale() == false else { status = "Refresh from iPhone first"; return }
        do {
            _ = try await request("command", method: "POST", body: CompanionState.encoder().encode(command))
            status = "Requested · awaiting iPhone acknowledgement"
        } catch { status = error.localizedDescription }
    }
}

struct CompanionConnectionFields: View {
    @ObservedObject var client: CompanionRelayClient
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Relay URL", text: $client.endpoint).textFieldStyle(.roundedBorder)
            SecureField("Relay token (this launch only)", text: $client.token).textFieldStyle(.roundedBorder)
            Toggle("Connect companion relay", isOn: $client.enabled)
            Text(client.status).font(.caption)
            Text("Keep iPhone TimeBite open for relay updates and controls.").font(.caption)
        }
    }
}

public struct CompanionDashboardView: View {
    @StateObject private var client = CompanionRelayClient()
    @State private var period = "AM"
    public init() {}
    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("iPhone Companion").font(.title)
                CompanionConnectionFields(client: client)
                if let state = client.state {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        if state.isStale(at: context.date) { Text("Stale snapshot · reconnect iPhone").foregroundStyle(.orange) }
                        if let action = state.active, let session = action.session {
                            Text(action.title).font(.headline)
                            ActivityRingView(progress: session.ringProgress(at: context.date), label: duration(session.elapsed(at: context.date)), secondaryLabel: session.status.rawValue)
                                .frame(width: 200, height: 200)
                            HStack {
                                Button(session.status == .running ? "Pause" : "Resume") {
                                    Task { await client.send(CompanionCommand(type: session.status == .running ? "pause" : "resume", action: action)) }
                                }
                                Button("Complete") { Task { await client.send(CompanionCommand(type: "complete", action: action)) } }
                            }.disabled(state.isStale(at: context.date))
                        } else {
                            Text("No live iPhone action")
                            ForEach(state.actions) { action in
                                Button("Start \(action.title)") { Task { await client.send(CompanionCommand(type: "start", action: action)) } }.disabled(state.isStale(at: context.date))
                            }
                        }
                    }
                    Picker("Day summary", selection: $period) {
                        ForEach(["AM", "PM", "Total"], id: \.self) { Text($0).tag($0) }
                    }.pickerStyle(.segmented)
                    if let value = state.periods.first(where: { $0.name == period }) {
                        ActivityRingView(progress: value.capturedSeconds / max(1, value.budgetSeconds), label: duration(value.capturedSeconds), secondaryLabel: period)
                            .frame(width: 200, height: 200)
                        Text("Health \(duration(value.healthSeconds)) · Calendar \(duration(value.calendarSeconds)) · Actions \(duration(value.actionSeconds))")
                        Text("Overlapping time counts once in the total.").font(.caption)
                    }
                    Text("Updated \(state.asOf.formatted())").font(.caption)
                } else { Text("Waiting for iPhone Health and calendar totals") }
            }.padding().frame(maxWidth: 600)
        }.task {
            while !Task.isCancelled {
                await client.tick(authority: nil)
                do { try await Task.sleep(nanoseconds: 5_000_000_000) } catch { break }
            }
        }
    }
    private func duration(_ seconds: Double) -> String { let m = max(0, Int(seconds / 60)); return "\(m / 60)h \(m % 60)m" }
}
#endif
