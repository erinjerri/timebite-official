#if os(watchOS)
import SwiftUI
import TimeBiteCore

public struct WatchCompanionView: View {
    @StateObject private var bridge = PairedWatchBridge.shared
    @State private var period = "AM"
    public init() {}
    public var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Text("TimeBite").font(.headline)
                Text(bridge.status).font(.caption2)
                Button("Refresh from iPhone") { bridge.requestRefresh() }
                if let state = bridge.state {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        if state.isStale(at: context.date) { Text("Stale · reconnect iPhone").foregroundStyle(.orange) }
                        if let action = state.active, let session = action.session {
                            Text(action.title)
                            ActivityRingView(progress: session.ringProgress(at: context.date), label: minutes(session.elapsed(at: context.date)), secondaryLabel: session.status.rawValue)
                                .frame(width: 120, height: 120)
                            Button(session.status == .running ? "Pause" : "Resume") {
                                bridge.send(CompanionCommand(type: session.status == .running ? "pause" : "resume", action: action))
                            }.disabled(state.isStale(at: context.date))
                            Button("Complete") { bridge.send(CompanionCommand(type: "complete", action: action)) }.disabled(state.isStale(at: context.date))
                        } else {
                            Text("No live action")
                            ForEach(state.actions) { action in
                                Button("Start \(action.title)") { bridge.send(CompanionCommand(type: "start", action: action)) }.disabled(state.isStale(at: context.date))
                            }
                        }
                    }
                    Picker("Day summary", selection: $period) {
                        ForEach(["AM", "PM", "Total"], id: \.self) { Text($0).tag($0) }
                    }
                    if let value = state.periods.first(where: { $0.name == period }) {
                        ActivityRingView(progress: value.capturedSeconds / max(1, value.budgetSeconds), label: minutes(value.capturedSeconds), secondaryLabel: period)
                            .frame(width: 120, height: 120)
                        Text("Health \(minutes(value.healthSeconds))")
                        Text("Calendar \(minutes(value.calendarSeconds))")
                        Text("Actions \(minutes(value.actionSeconds))")
                        Text("Overlaps count once in total").font(.caption2)
                    }
                    Text("Updated \(state.asOf.formatted(date: .omitted, time: .shortened))").font(.caption2)
                } else { Text("Waiting for real iPhone data") }
            }
        }.onAppear { bridge.requestRefresh() }
    }
    private func minutes(_ seconds: Double) -> String { let m = max(0, Int(seconds / 60)); return "\(m / 60)h \(m % 60)m" }
}
#endif
