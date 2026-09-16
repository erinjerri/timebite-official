import SwiftUI
import TimeBiteCore
import TimeBiteData

@MainActor
public final class ActivityLoopController: ObservableObject {
    @Published public private(set) var snapshot = ActivitySnapshot()
    @Published public var errorMessage: String?
    private let store: LocalActivityStore

    public init(store: LocalActivityStore = LocalActivityStore()) {
        self.store = store
        refresh()
    }

    public var currentSession: ActivitySession? {
        snapshot.sessions.first { $0.status != .completed }
    }

    public var currentAction: Action? {
        guard let currentSession else { return nil }
        return snapshot.actions.first { $0.id == currentSession.actionID }
    }

    public func refresh() {
        do { snapshot = try store.snapshot() }
        catch { errorMessage = error.localizedDescription }
    }

    public func create(title: String, minutes: Int) {
        perform { _ = try store.createAction(title: title, targetDuration: Double(minutes) * 60) }
    }

    public func start(_ action: Action) {
        perform { _ = try store.start(actionID: action.id) }
    }

    public func pause() {
        guard let currentSession else { return }
        perform { try store.pause(sessionID: currentSession.id) }
    }

    public func resume() {
        guard let currentSession else { return }
        perform { try store.resume(sessionID: currentSession.id) }
    }

    public func complete() {
        guard let currentSession else { return }
        perform { _ = try store.complete(sessionID: currentSession.id) }
    }

    private func perform(_ operation: () throws -> Void) {
        do { try operation(); errorMessage = nil; refresh() }
        catch { errorMessage = error.localizedDescription }
    }
}

public struct ActivityLoopView: View {
    @StateObject private var controller = ActivityLoopController()
    @State private var draftTitle = ""
    @State private var draftMinutes = 25

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    currentActivity
                    createForm
                    todayList
                    dailyRing
                }
                .frame(maxWidth: 720)
                .padding()
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("TimeBite")
            .alert("Activity error", isPresented: Binding(
                get: { controller.errorMessage != nil },
                set: { if !$0 { controller.errorMessage = nil } }
            )) {
                Button("OK") { controller.errorMessage = nil }
            } message: {
                Text(controller.errorMessage ?? "")
            }
        }
    }

    @ViewBuilder private var currentActivity: some View {
        if let session = controller.currentSession, let action = controller.currentAction {
            TimelineView(.periodic(from: .now, by: 1)) { timeline in
                VStack(spacing: 16) {
                    Text(action.title).font(.title2).bold()
                    ActivityRingView(progress: session.ringProgress(at: timeline.date),
                                     label: formatted(session.elapsed(at: timeline.date)))
                        .frame(width: 160, height: 160)
                    HStack {
                        if session.status == .running {
                            Button("Pause") { controller.pause() }
                        } else {
                            Button("Resume") { controller.resume() }
                        }
                        Button("Complete") { controller.complete() }
                            .buttonStyle(.borderedProminent)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
            }
        } else {
            Text("Choose an action to start").foregroundStyle(.secondary)
        }
    }

    private var createForm: some View {
        VStack(alignment: .leading) {
            Text("Create action").font(.headline)
            TextField("Action title", text: $draftTitle)
            Stepper("Target: \(draftMinutes) minutes", value: $draftMinutes, in: 1...480)
            Button("Add action") {
                controller.create(title: draftTitle, minutes: draftMinutes)
                if controller.errorMessage == nil { draftTitle = "" }
            }
            .disabled(draftTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private var todayList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Today's actions").font(.headline)
            ForEach(controller.snapshot.actions.filter { Calendar.current.isDateInToday($0.plannedStart ?? $0.createdAt) }) { action in
                HStack {
                    VStack(alignment: .leading) {
                        Text(action.title)
                        Text("\(Int((action.plannedDuration ?? 0) / 60)) min · \(action.executionState.rawValue)")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if action.executionState == .notStarted {
                        Button("Start") { controller.start(action) }
                            .disabled(controller.currentSession != nil)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var dailyRing: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            let progress = DailyProgress.calculate(actions: controller.snapshot.actions,
                                                   sessions: controller.snapshot.sessions,
                                                   at: timeline.date)
            HStack {
                ActivityRingView(progress: progress.ringProgress, label: "Today")
                    .frame(width: 90, height: 90)
                Text("\(progress.completedActions) completed · \(Int(progress.executedDuration / 60)) active min")
                    .font(.subheadline)
            }
        }
    }

    private func formatted(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}
