import SwiftUI
import TimeBiteCore

#if os(iOS)
import EventKit

@MainActor
private final class CalendarActivityController: ObservableObject {
    @Published private(set) var entries: [TodayActivityEntry] = []
    @Published private(set) var isConnected = false
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let store = EKEventStore()

    init() {
        let status = EKEventStore.authorizationStatus(for: .event)
        if #available(iOS 17.0, *) {
            isConnected = status == .fullAccess
        } else {
            isConnected = status == .authorized
        }
    }

    func refreshIfConnected() async {
        guard isConnected else { return }
        await refresh()
    }

    func connect() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let granted: Bool
            if #available(iOS 17.0, *) {
                granted = try await store.requestFullAccessToEvents()
            } else {
                granted = try await withCheckedThrowingContinuation { continuation in
                    store.requestAccess(to: .event) { allowed, error in
                        if let error { continuation.resume(throwing: error) }
                        else { continuation.resume(returning: allowed) }
                    }
                }
            }
            isConnected = granted
            if granted { await refresh() }
            else { errorMessage = "Calendar access was not granted." }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refresh() async {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)
        let selectedProviders = TimeBiteCalendarProvider.selected
        guard !selectedProviders.isEmpty else {
            entries = []
            return
        }
        let calendars = store.calendars(for: .event).filter { calendar in
            selectedProviders.contains { $0.matches(calendar) }
        }
        let events = store.events(matching: store.predicateForEvents(withStart: start, end: end, calendars: calendars))
        entries = events.filter { !$0.isAllDay }.map { event in
            TodayActivityEntry(
                id: "calendar:\(event.eventIdentifier ?? UUID().uuidString)",
                title: event.title?.isEmpty == false ? event.title! : "Calendar event",
                source: .calendar,
                startDate: event.startDate,
                endDate: event.endDate,
                duration: max(0, event.endDate.timeIntervalSince(event.startDate))
            )
        }
    }
}

public struct TimeBiteTodayView: View {
    @ObservedObject private var activity: ActivityLoopController
    @StateObject private var calendar = CalendarActivityController()
    @StateObject private var capture = HandwrittenPlanCaptureController()
    @State private var title = ""
    @State private var durationHours = 0
    @State private var durationMinutes = 30
    @FocusState private var actionFieldFocused: Bool
    private var minutes: Int { durationHours * 60 + durationMinutes }
    private var canCreate: Bool { !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && minutes > 0 }
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme

    public init() { self.activity = ActivityLoopController() }

    init(activity: ActivityLoopController) { self.activity = activity }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                activeSession
                createAction
                progressSection
                plannedActions
                capturedToday
            }
            .frame(maxWidth: 720)
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 32)
            .frame(maxWidth: .infinity)
        }
        .background {
            TimeBitePalette.background(for: colorScheme)

                .ignoresSafeArea()
        }
        .tint(accent)
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { actionFieldFocused = false }
            }
        }
        .task {
            if UserDefaults.standard.bool(forKey: "timebite.health.authorizationRequested.v1") {
                await activity.refreshHealth()
            }
            await calendar.refreshIfConnected()
            activity.updateCalendarEntries(calendar.entries)
        }
        .onChange(of: calendar.entries) { entries in
            activity.updateCalendarEntries(entries)
        }
        .onChange(of: scenePhase) { phase in
            guard phase == .active else { return }
            activity.refresh()
            Task {
                await activity.refreshHealth()
                await calendar.refreshIfConnected()
            }
        }
        .refreshable {
            await activity.refreshHealth()
            await calendar.refreshIfConnected()
            activity.updateCalendarEntries(calendar.entries)
        }
        .alert("TimeBite", isPresented: errorIsPresented) {
            Button("OK") {
                activity.errorMessage = nil
                calendar.errorMessage = nil
                capture.errorMessage = nil
            }
        } message: {
            Text(activity.errorMessage ?? calendar.errorMessage ?? capture.errorMessage ?? "")
        }
    }

    private var summary: TodayActivitySummary { activity.todaySummary() }

    private var header: some View {
        Masthead(title: "Make time count.", subtitle: "TODAY / TIMEBITE")
    }

    private var progressSection: some View {
        VStack(spacing: 18) {
            TimelineView(.periodic(from: .now, by: 30)) { context in
                TrackedDayRingView(summary: activity.todaySummary(at: context.date), snapshot: activity.snapshot, now: context.date)
            }
            healthCaptureStatus

            AdaptiveRow {
                metric(value: durationLabel(summary.trackedDuration), label: "Captured")
                metric(value: durationLabel(summary.dayInterval.duration), label: "Day budget")
            }
        }
    }

    private var healthCaptureStatus: some View {
        VStack(alignment: .leading, spacing: 8) {
            AdaptiveRow {
                Label("Apple Health", systemImage: "heart.fill")
                    .foregroundStyle(TimeBitePalette.violet)
                Spacer(minLength: 0)
                Button("Refresh") { Task { await activity.refreshHealth() } }
                    .frame(minWidth: 44, minHeight: 44)
                    .disabled(activity.healthState == .loading || activity.healthState == .requesting)
            }
            switch activity.healthState {
            case .loading, .requesting:
                ProgressView("Loading Health activity…")
            case .loaded(let date):
                if activity.healthRecords.isEmpty {
                    Text("No readable sleep, workout or mindfulness records for today. Check today's data and TimeBite's read access in Apple Health.")
                    #if targetEnvironment(simulator)
                    Text("Simulator uses its own Health store. Add today's sample data in the simulator's Health app to test the rings.")
                    #endif
                } else {
                    ForEach([HealthActivityType.sleep, .workout, .mindfulness], id: \.rawValue) { type in
                        let records = activity.healthRecords.filter { $0.type == type }
                        let intervals = records.map { DateInterval(start: $0.startDate, end: $0.endDate).clamped(to: summary.dayInterval) }
                        Text("\(type.rawValue.capitalized): \(durationLabel(IntervalAggregation.mergedDuration(intervals)))")
                            .monospacedDigit()
                    }
                }
                Text("Updated \(date.formatted(date: .omitted, time: .shortened))")
            case .failed(let message):
                Text("Health could not refresh: \(message)")
            case .unavailable:
                Text("Apple Health is unavailable on this device.")
            case .notRequested:
                Text("Health setup has not been completed.")
            case .authorized:
                Text("Waiting for today's Health records.")
            }
        }
        .font(TimeBiteTypography.font(.caption))
        .foregroundStyle(secondaryText)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder private var activeSession: some View {
        if let session = activity.currentSession,
           let action = activity.currentAction {
            TimelineView(.periodic(from: .now, by: 1)) { timeline in
                sectionCard {
                    sectionTitle("Live Action")
                    VStack(alignment: .center, spacing: 16) {
                        ActivityRingView(
                            progress: session.ringProgress(at: timeline.date),
                            label: formatted(session.elapsed(at: timeline.date)),
                            secondaryLabel: "Elapsed",
                            accentColor: accent,
                            lineWidth: 16
                        )
                        .frame(width: 248, height: 248)

                        VStack(alignment: .leading, spacing: 10) {
                            Text(action.title)
                                .font(TimeBiteTypography.font(.title3, weight: .semibold))
                                .foregroundStyle(primaryText)
                                .fixedSize(horizontal: false, vertical: true)
                            Text("\(durationLabel(session.elapsed(at: timeline.date))) elapsed")
                                .font(TimeBiteTypography.font(.caption))
                                .foregroundStyle(secondaryText)
                            AdaptiveRow {
                                Button(session.status == .running ? "Pause" : "Resume") {
                                    session.status == .running ? activity.pause() : activity.resume()
                                }
                                .buttonStyle(.bordered)
                                Button("Complete") { activity.complete() }
                                    .buttonStyle(.borderedProminent)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
        } else {
            sectionCard {
                sectionTitle("Live Action")
                ActivityRingView(progress: 0, label: "No active action", secondaryLabel: "Start an action to track time", accentColor: accent, lineWidth: 16)
                    .frame(width: 248, height: 248)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var createAction: some View {
        sectionCard {
            HStack {
                sectionTitle("Create Action")
                Spacer()
                HandwrittenPlanCaptureButton(capture: capture, onSave: { draft in
                    activity.importCaptureDraft(draft)
                }, iconOnly: true)
            }
            TextField("Add an action to your goal or project.", text: $title, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...4)
                .focused($actionFieldFocused)
                .textInputAutocapitalization(.sentences)
                .font(TimeBiteTypography.font(.body))
                .foregroundStyle(primaryText)
                .tint(accent)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .padding(16)
                .background(elevatedSurface, in: Rectangle())
                .contentShape(Rectangle())
                .onTapGesture { actionFieldFocused = true }
                .accessibilityLabel("Action title")
            Text("Duration").font(TimeBiteTypography.font(.body, weight: .semibold))
            AdaptiveRow {
                Picker("Hours", selection: $durationHours) {
                    ForEach(0...24, id: \.self) { Text("\($0) hours").tag($0) }
                }
                Picker("Minutes", selection: $durationMinutes) {
                    ForEach(0...60, id: \.self) { Text("\($0) min").tag($0) }
                }
            }
            .pickerStyle(.menu)
            .font(TimeBiteTypography.font(.body))
            .frame(minHeight: 44)
            .foregroundStyle(primaryText)
            Text("\(durationLabel(Double(minutes) * 60)) total")
                .font(TimeBiteTypography.font(.caption))
                .foregroundStyle(secondaryText)
            Button("Create Action") {
                activity.create(title: title, minutes: minutes)
                if activity.errorMessage == nil { title = ""; actionFieldFocused = false }
            }
            .font(TimeBiteTypography.font(.body, weight: .semibold))
            .frame(maxWidth: .infinity)
            .frame(minHeight: 44)
            .foregroundStyle(.white)
            .background(TimeBitePalette.accentFill, in: Rectangle())
            .disabled(!canCreate)
            .opacity(canCreate ? 1 : 0.55)
        }
    }

    private var plannedActions: some View {
        sectionCard {
            sectionTitle("TimeBite actions")
            let actions = activity.snapshot.actions
                .filter { $0.executionState != .completed }
                .sorted { $0.createdAt > $1.createdAt }

            if actions.isEmpty {
                Text("No actions yet. Add one or scan a paper plan.")
                    .font(TimeBiteTypography.font(.body))
                    .foregroundStyle(secondaryText)
            } else {
                ForEach(actions) { action in
                    TimeBlockRow(action: action, activity: activity)
                }
            }
        }
    }

    private var capturedToday: some View {
        sectionCard {
            sectionTitle("Captured today")
            if summary.entries.isEmpty {
                Text("No activity captured yet.")
                    .font(TimeBiteTypography.font(.body))
                    .foregroundStyle(secondaryText)
            } else {
                ForEach(summary.entries) { entry in entryRow(entry) }
            }
        }
    }

    private func metric(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(TimeBiteTypography.font(.title3, weight: .bold))
                .foregroundStyle(primaryText)
            Text(label)
                .font(TimeBiteTypography.font(.caption, weight: .semibold))
                .foregroundStyle(secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(elevatedSurface.opacity(0.74), in: Rectangle())
    }

    private func entryRow(_ entry: TodayActivityEntry) -> some View {
        AdaptiveRow {
            Image(systemName: entry.source == .calendar ? "calendar" : entry.source == .health ? "heart.fill" : "timer")
                .foregroundStyle(accent)
                .frame(minWidth: 44, minHeight: 44)
                .background(accent.opacity(0.13), in: Rectangle())
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title)
                    .font(TimeBiteTypography.font(.body, weight: .semibold))
                    .foregroundStyle(primaryText)
                    .fixedSize(horizontal: false, vertical: true)
                Text("\(entry.source.rawValue) · \(durationLabel(entry.duration))")
                    .font(TimeBiteTypography.font(.caption))
                    .foregroundStyle(secondaryText)
            }
            Spacer()
        }
        .padding(12)
        .background(elevatedSurface.opacity(0.82), in: Rectangle())
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title.uppercased())
            .font(TimeBiteTypography.font(.caption, weight: .semibold))
            .tracking(2)
            .foregroundStyle(primaryText)
    }

    private func sectionCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            content()
        }
        .padding(16)
        .background(
            Rectangle()
                .fill(surface)
                .overlay(
                    Rectangle()
                        .stroke(TimeBitePalette.border(for: colorScheme), lineWidth: 1)
                )

        )
    }

    private var errorIsPresented: Binding<Bool> {
        Binding(
            get: { activity.errorMessage != nil || calendar.errorMessage != nil || capture.errorMessage != nil },
            set: { shown in
                if !shown {
                    activity.errorMessage = nil
                    calendar.errorMessage = nil
                    capture.errorMessage = nil
                }
            }
        )
    }

    private var accent: Color { TimeBitePalette.teal }
    private var surface: Color { TimeBitePalette.surface(for: colorScheme) }
    private var elevatedSurface: Color { TimeBitePalette.elevatedSurface(for: colorScheme) }
    private var primaryText: Color { TimeBitePalette.primaryText(for: colorScheme) }
    private var secondaryText: Color { TimeBitePalette.secondaryText(for: colorScheme) }

    private func durationLabel(_ seconds: TimeInterval) -> String {
        let totalMinutes = max(0, Int(seconds.rounded() / 60))
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 { return minutes == 0 ? "\(hours)h" : "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }

    private func formatted(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}
#endif
