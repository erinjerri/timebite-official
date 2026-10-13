import SwiftUI
import TimeBiteCore
import TimeBiteData
import TimeBiteHealth

public enum HealthConnectionState: Equatable {
    case unavailable
    case notRequested
    case requesting
    case authorized
    case loading
    case loaded(Date)
    case failed(String)
}

@MainActor
public final class ActivityLoopController: ObservableObject {
    @Published public private(set) var snapshot = ActivitySnapshot()
    @Published public var errorMessage: String?
    @Published public private(set) var healthRecords: [HealthActivityRecord] = []
    @Published public private(set) var calendarEntries: [TodayActivityEntry] = []
    @Published public private(set) var healthState: HealthConnectionState
    private let store: LocalActivityStore
    private let healthProvider: HealthActivityProvider
    private var requestedHealthAuthorization: Bool {
        get { UserDefaults.standard.bool(forKey: "timebite.health.authorizationRequested.v1") }
        set { UserDefaults.standard.set(newValue, forKey: "timebite.health.authorizationRequested.v1") }
    }

    public init(
        store: LocalActivityStore = LocalActivityStore(),
        healthProvider: HealthActivityProvider = HealthKitActivityProvider()
    ) {
        self.store = store
        self.healthProvider = healthProvider
        if healthProvider.isAvailable {
            self.healthState = UserDefaults.standard.bool(forKey: "timebite.health.authorizationRequested.v1") ? .authorized : .notRequested
        } else {
            self.healthState = .unavailable
        }
        refresh()
        #if os(iOS)
        PairedWatchBridge.shared.stateProvider = { [weak self] in
            self?.companionState()
        }
        PairedWatchBridge.shared.commandHandler = { [weak self] command in
            guard let self else { throw CompanionControlError.unavailable }
            try self.handleCompanionCommand(command)
        }
        PairedWatchBridge.shared.publish()
        #endif
        if requestedHealthAuthorization {
            Task { await refreshHealth() }
        }
    }

    public var currentSession: ActivitySession? {
        snapshot.sessions.first { $0.status != .completed }
    }

    public var currentAction: Action? {
        guard let currentSession else { return nil }
        return snapshot.actions.first { $0.id == currentSession.actionID }
    }

    public func refresh() {
        do {
            snapshot = try store.snapshot()
            #if os(iOS)
            PairedWatchBridge.shared.publish()
            #endif
        }
        catch { errorMessage = error.localizedDescription }
    }

    public func todaySummary(at date: Date = Date()) -> TodayActivitySummary {
        TodayActivitySummary.calculate(
            actions: snapshot.actions,
            sessions: snapshot.sessions,
            healthRecords: healthRecords,
            calendarEntries: calendarEntries,
            at: date
        )
    }

    public func updateCalendarEntries(_ entries: [TodayActivityEntry]) {
        calendarEntries = entries
        #if os(iOS)
        PairedWatchBridge.shared.publish()
        #endif
    }

    public func saveGoal(_ goal: Goal) {
        perform { try store.saveGoal(goal) }
    }

    public func create(title: String, minutes: Int) {
        perform { _ = try store.createAction(title: title, targetDuration: Double(minutes) * 60) }
    }

    #if os(iOS)
    func importCaptureDraft(_ draft: TimeBiteCaptureDraft) {
        perform {
            _ = try store.importPlan(
                projectTitle: draft.project,
                goalTitle: draft.goal,
                actions: draft.tasks.map {
                    ImportedPlanAction(title: $0.title, plannedDuration: Double($0.allocatedMinutes) * 60)
                },
                rawRecognizedText: draft.rawRecognizedText,
                source: draft.source
            )
        }
    }
    #endif

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

    public func connectHealth() {
        guard healthProvider.isAvailable else {
            healthState = .unavailable
            return
        }
        Task {
            healthState = .requesting
            do {
                try await healthProvider.requestAuthorization()
                requestedHealthAuthorization = true
                healthState = .authorized
                await refreshHealth()
            } catch {
                healthState = .failed(Self.healthMessage(for: error))
            }
        }
    }

    public func refreshHealth() async {
        guard healthProvider.isAvailable else {
            healthState = .unavailable
            return
        }
        healthState = .loading
        do {
            let interval = Calendar.current.dateInterval(of: .day, for: Date()) ?? DateInterval(start: Date(), duration: 86_400)
            healthRecords = try await healthProvider.fetchActivity(for: interval)
            healthState = .loaded(Date())
            #if os(iOS)
            PairedWatchBridge.shared.publish()
            #endif
        } catch {
            healthState = .failed(Self.healthMessage(for: error))
        }
    }

    private func perform(_ operation: () throws -> Void) {
        do { try operation(); errorMessage = nil; refresh() }
        catch { errorMessage = error.localizedDescription }
    }

    private static func healthMessage(for error: Error) -> String {
        if let providerError = error as? HealthActivityProviderError {
            switch providerError {
            case .unavailable, .unsupportedPlatform:
                return "Health data isn't available on this device."
            case .healthDataTypeUnavailable:
                return "HealthKit sleep or workout types were unavailable."
            }
        }
        return error.localizedDescription
    }
}

public struct ActivityLoopView: View {
    @StateObject private var controller = ActivityLoopController()
    #if os(iOS)
    @StateObject private var capture = HandwrittenPlanCaptureController()
    #endif
    @State private var draftTitle = ""
    @State private var draftMinutes = 25
    @Environment(\.scenePhase) private var scenePhase

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    currentActivity
                    createForm
                    #if os(iOS)
                    captureForm
                    #endif
                    healthPanel
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
            #if os(iOS)
            .alert("Capture error", isPresented: Binding(
                get: { capture.errorMessage != nil },
                set: { if !$0 { capture.errorMessage = nil } }
            )) {
                Button("OK") { capture.errorMessage = nil }
            } message: {
                Text(capture.errorMessage ?? "")
            }
            #endif
            .onChange(of: scenePhase) { phase in
                guard phase == .active else { return }
                Task { await controller.refreshHealth() }
            }
        }
    }

    @ViewBuilder private var currentActivity: some View {
        if let session = controller.currentSession, let action = controller.currentAction {
            TimelineView(.periodic(from: .now, by: 1)) { timeline in
                VStack(spacing: 16) {
                    Text(action.title).font(TimeBiteTypography.font(.title2)).bold()
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
            Text("Create action").font(TimeBiteTypography.font(.headline))
            TextField("Action title", text: $draftTitle)
            Stepper("Target: \(draftMinutes) minutes", value: $draftMinutes, in: 1...480)
            Button("Add action") {
                controller.create(title: draftTitle, minutes: draftMinutes)
                if controller.errorMessage == nil { draftTitle = "" }
            }
            .disabled(draftTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    #if os(iOS)
    private var captureForm: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Paper capture").font(TimeBiteTypography.font(.headline))
            HandwrittenPlanCaptureButton(capture: capture) { draft in
                controller.importCaptureDraft(draft)
            }
        }
    }
    #endif

    private var todayList: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            let summary = controller.todaySummary(at: timeline.date)
            VStack(alignment: .leading, spacing: 8) {
                Text("Today").font(TimeBiteTypography.font(.headline))
                ForEach(summary.entries) { entry in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(entry.title)
                            Text("\(durationLabel(entry.duration)) · \(entry.source.rawValue)")
                                .font(TimeBiteTypography.font(.caption)).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if entry.source == .timeBite,
                           let action = controller.snapshot.actions.first(where: { "timebite:\($0.id.uuidString)" == entry.id }),
                           action.executionState == .notStarted {
                            Button("Start") { controller.start(action) }
                                .disabled(controller.currentSession != nil)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private var healthPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Health").font(TimeBiteTypography.font(.headline))
            Text(healthSubtitle)
                .font(TimeBiteTypography.font(.subheadline))
                .foregroundStyle(.secondary)
            HStack {
                switch controller.healthState {
                case .notRequested, .failed:
                    Button("Connect Health") { controller.connectHealth() }
                case .authorized, .loaded:
                    Button("Refresh") { Task { await controller.refreshHealth() } }
                case .loading, .requesting:
                    ProgressView()
                case .unavailable:
                    EmptyView()
                }
            }
        }
    }

    private var healthSubtitle: String {
        switch controller.healthState {
        case .unavailable:
            return "Health data isn't available on this device."
        case .notRequested:
            return "Use sleep and workouts to fill your TimeBite day."
        case .requesting:
            return "Requesting permission..."
        case .authorized:
            return "Connected. Sleep + Workouts."
        case .loading:
            return "Loading..."
        case .loaded:
            return controller.healthRecords.isEmpty ? "Connected. No sleep or workouts found today." : "Connected. Sleep + Workouts."
        case .failed(let message):
            return message
        }
    }

    private var dailyRing: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            let progress = controller.todaySummary(at: timeline.date)
            HStack {
                ActivityRingView(progress: progress.trackedDayProgress, label: "Today")
                    .frame(width: 90, height: 90)
                Text("\(durationLabel(progress.trackedDuration)) tracked")
                    .font(TimeBiteTypography.font(.subheadline))
            }
        }
    }

    private func formatted(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    private func durationLabel(_ seconds: TimeInterval) -> String {
        let totalMinutes = max(0, Int(seconds.rounded() / 60))
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 {
            return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h"
        }
        return "\(minutes)m"
    }
}
