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
    @State private var minutes = 30
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme

    public init() { self.activity = ActivityLoopController() }

    init(activity: ActivityLoopController) { self.activity = activity }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                progressSection
                activeSession
                createAction
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
        .task {
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
            ActivityRingView(
                progress: summary.trackedDayProgress,
                label: "\(durationLabel(summary.trackedDuration)) tracked",
                secondaryLabel: "\(Int((summary.trackedDayProgress * 100).rounded()))% of today",
                accentColor: TimeBitePalette.totalRingColor,
                lineWidth: 18
            )
            .frame(width: 248, height: 248)
            .frame(maxWidth: .infinity)

            AdaptiveRow {
                metric(value: durationLabel(summary.trackedDuration), label: "Captured")
                metric(value: durationLabel(summary.dayInterval.duration), label: "Day budget")
            }
        }
    }

    @ViewBuilder private var activeSession: some View {
        if let session = activity.currentSession,
           let action = activity.currentAction {
            TimelineView(.periodic(from: .now, by: 1)) { timeline in
                sectionCard {
                    sectionTitle("Now")
                    AdaptiveRow {
                        ActivityRingView(
                            progress: session.ringProgress(at: timeline.date),
                            label: formatted(session.elapsed(at: timeline.date)),
                            secondaryLabel: "Elapsed",
                            accentColor: accent,
                            lineWidth: 10
                        )
                        .frame(width: 128, height: 128)

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
            TextField("Add an action to your goal or project.", text: $title)
                .font(TimeBiteTypography.font(.body))
                .foregroundStyle(primaryText)
                .padding(16)
                .background(elevatedSurface, in: Rectangle())
            Stepper("Duration: \(minutes) min", value: $minutes, in: 5...480, step: 5)
                .font(TimeBiteTypography.font(.body, weight: .semibold))
                .foregroundStyle(primaryText)
            Button("Create Action") {
                activity.create(title: title, minutes: minutes)
                if activity.errorMessage == nil { title = "" }
            }
            .font(TimeBiteTypography.font(.body, weight: .semibold))
            .frame(maxWidth: .infinity)
            .frame(minHeight: 44)
            .foregroundStyle(.white)
            .background(TimeBitePalette.accentFill, in: Rectangle())
            .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.55 : 1)
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
