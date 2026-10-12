import AuthenticationServices
import EventKit
import SwiftUI
import TimeBiteCore
import TimeBiteHealth

#if os(iOS)
enum TimeBiteCalendarProvider: String, CaseIterable, Identifiable {
    case apple
    case google
    case outlook

    var id: String { rawValue }

    var title: String {
        switch self {
        case .apple: return "iCloud Calendar"
        case .google: return "Google Calendar"
        case .outlook: return "Outlook Calendar"
        }
    }

    var subtitle: String {
        switch self {
        case .apple: return "Events from iCloud and calendars on this device"
        case .google: return "Google calendars connected in iOS Settings"
        case .outlook: return "Microsoft and Exchange calendars on this device"
        }
    }

    var icon: String {
        switch self {
        case .apple: return "apple.logo"
        case .google: return "g.circle.fill"
        case .outlook: return "envelope.fill"
        }
    }

    var tint: Color {
        switch self {
        case .apple: return TimeBitePalette.sky
        case .google: return TimeBitePalette.gold
        case .outlook: return TimeBitePalette.blue
        }
    }

    var defaultsKey: String { "timebite.calendar.\(rawValue).enabled.v1" }

    static var selected: Set<Self> {
        Set(allCases.filter { UserDefaults.standard.bool(forKey: $0.defaultsKey) })
    }

    func matches(_ calendar: EKCalendar) -> Bool {
        let source = calendar.source.title.lowercased()
        switch self {
        case .apple:
            return calendar.source.sourceType == .local || source.contains("icloud") || source.contains("apple")
        case .google:
            return source.contains("google") || source.contains("gmail")
        case .outlook:
            return calendar.source.sourceType == .exchange || source.contains("outlook") || source.contains("microsoft")
        }
    }
}

public struct TimeBiteRootView: View {
    @AppStorage("timebite.onboarding.completed.v1") private var completedOnboarding = false

    public init() {}

    public var body: some View {
        if completedOnboarding {
            TimeBiteTabsView()
        } else {
            TimeBiteOnboardingView {
                completedOnboarding = true
            }
        }
    }
}

private struct TimeBiteOnboardingView: View {
    private enum Step: Int, CaseIterable {
        case welcome
        case calendar
        case health
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var step: Step = .welcome
    @State private var appleUserID = UserDefaults.standard.string(forKey: "timebite.apple.userID.v1")
    @State private var emailAddress = UserDefaults.standard.string(forKey: "timebite.manual.email.v1") ?? ""
    @State private var calendarSelection = TimeBiteCalendarProvider.selected
    @State private var calendarEntries: [TodayActivityEntry] = []
    @State private var healthRecords: [HealthActivityRecord] = []
    @State private var includeHealth = true
    @State private var isLoading = false
    @State private var errorMessage: String?
    @Environment(\.colorScheme) private var colorScheme

    private let eventStore = EKEventStore()
    private let healthProvider = HealthKitActivityProvider()
    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            progressHeader
            Group {
                switch step {
                case .welcome: welcome
                case .calendar: calendar
                case .health: health
                }
            }
            .frame(maxWidth: 620, maxHeight: .infinity)
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
        }
        .background {
            TimeBitePalette.background(for: colorScheme)

                .ignoresSafeArea()
        }
        .tint(TimeBitePalette.teal)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.24), value: step)
        .alert("TimeBite", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var progressHeader: some View {
        StagePips(stage: step.rawValue + 1, total: Step.allCases.count,
                  title: ["Welcome", "Calendar", "Health"][step.rawValue])
            .padding(24)
    }

    private var welcome: some View {
        ScrollView { VStack(spacing: 24) {
            Spacer()
            ZStack {
                Circle().fill(TimeBitePalette.teal.opacity(0.12))
                ActivityRingView(
                    progress: 0.68,
                    label: "TimeBite",
                    secondaryLabel: "Make your time visible",
                    accentColor: TimeBitePalette.teal,
                    lineWidth: 15
                )
                .padding(18)
            }
            .frame(width: 230, height: 230)

            VStack(spacing: 10) {
                Text("Welcome to TimeBite")
                    .font(TimeBiteTypography.font(.largeTitle, weight: .bold))
                    .foregroundStyle(primaryText)
                    .multilineTextAlignment(.center)
                Text("Bring your day together, then focus on one action at a time.")
                    .font(TimeBiteTypography.font(.body))
                    .foregroundStyle(secondaryText)
                    .multilineTextAlignment(.center)
            }
            Spacer()

            VStack(spacing: 12) {
                SignInWithAppleButton(.continue) { _ in } onCompletion: { result in
                    switch result {
                    case .success(let authorization):
                        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else { return }
                        appleUserID = credential.user
                        UserDefaults.standard.set(credential.user, forKey: "timebite.apple.userID.v1")
                        step = .calendar
                    case .failure(let error):
                        handleAppleSignInError(error)
                    }
                }
                .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                .frame(minHeight: 52)
                .clipShape(Rectangle())
                .accessibilityHint("Signs in and continues to calendar setup")

                HStack(spacing: 10) {
                    Rectangle().fill(border).frame(height: 1)
                    Text("or")
                        .font(TimeBiteTypography.font(.caption, weight: .semibold))
                        .foregroundStyle(secondaryText)
                    Rectangle().fill(border).frame(height: 1)
                }

                manualEmailForm
            }
        }
        }
    }

    private var manualEmailForm: some View {
        VStack(spacing: 10) {
            TextField("Email address", text: $emailAddress)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(TimeBiteTypography.font(.body))
                .foregroundStyle(primaryText)
                .padding(.horizontal, 14)
                .frame(minHeight: 52)
                .background(surface, in: Rectangle())
                .overlay(Rectangle().stroke(border, lineWidth: 1))
                .submitLabel(.continue)
                .onSubmit(continueWithEmail)

            Button(action: continueWithEmail) {
                Text("Continue with Email")
                    .font(TimeBiteTypography.font(.body, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 52)
                    .foregroundStyle(.white)
                    .background(TimeBitePalette.accentFill, in: Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private var calendar: some View {
        ScrollView { VStack(alignment: .leading, spacing: 22) {
            Spacer(minLength: 24)
            onboardingTitle(
                icon: "calendar",
                title: "Add your calendars",
                subtitle: "Choose which calendar accounts should fill your day. TimeBite only reads events after you approve access."
            )

            VStack(spacing: 0) {
                ForEach(Array(TimeBiteCalendarProvider.allCases.enumerated()), id: \.element.id) { index, provider in
                    providerToggle(provider)
                    if index < TimeBiteCalendarProvider.allCases.count - 1 {
                        Divider().padding(.leading, 58)
                    }
                }
            }
            .background(surface, in: Rectangle())
            .overlay(Rectangle().stroke(border, lineWidth: 1))

            Text("Google and Outlook accounts must already be added under iOS Settings > Calendar > Accounts.")
                .font(TimeBiteTypography.font(.caption))
                .foregroundStyle(secondaryText)
            Spacer()
            primaryButton("Continue", loading: isLoading) {
                Task { await connectCalendars() }
            }
        }
    }
    }

    private var health: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                onboardingTitle(
                    icon: "heart.fill",
                    title: "Fill in the rest of your day",
                    subtitle: "HealthKit can add sleep, workouts, and mindfulness so your ring starts with the time already accounted for."
                )

                Toggle(isOn: $includeHealth) {
                    Label {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Apple Health")
                                .font(TimeBiteTypography.font(.body, weight: .semibold))
                                .foregroundStyle(primaryText)
                            Text("Sleep, workouts, and mindfulness")
                                .font(TimeBiteTypography.font(.caption))
                                .foregroundStyle(secondaryText)
                        }
                    } icon: {
                        Image(systemName: "heart.fill").foregroundStyle(TimeBitePalette.violet)
                    }
                }
                .padding(16)
                .background(surface, in: Rectangle())
                .overlay(Rectangle().stroke(border, lineWidth: 1))

                syncedPreview

                primaryButton(previewSummary.entries.isEmpty ? "Load My Day" : "Finish Setup", loading: isLoading) {
                    Task {
                        if previewSummary.entries.isEmpty && includeHealth {
                            await connectHealth()
                        } else {
                            onComplete()
                        }
                    }
                }

                if includeHealth && previewSummary.entries.isEmpty {
                    Button("Continue without Health") { onComplete() }
                        .font(TimeBiteTypography.font(.body, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(secondaryText)
                }
            }
            .padding(.top, 28)
        }
    }

    private var syncedPreview: some View {
        VStack(spacing: 18) {
            SourceActivityRingView(
                calendarProgress: calendarDuration / 86_400,
                healthProgress: healthDuration / 86_400,
                label: durationLabel(previewSummary.trackedDuration)
            )
            .frame(width: 220, height: 220)

            AdaptiveRow {
                legend(color: TimeBitePalette.sky, title: "Calendar", value: durationLabel(calendarDuration))
                legend(color: TimeBitePalette.violet, title: "Health", value: durationLabel(healthDuration))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(surface, in: Rectangle())
        .overlay(Rectangle().stroke(border, lineWidth: 1))
    }

    private func providerToggle(_ provider: TimeBiteCalendarProvider) -> some View {
        Toggle(isOn: Binding(
            get: { calendarSelection.contains(provider) },
            set: { selected in
                if selected { calendarSelection.insert(provider) }
                else { calendarSelection.remove(provider) }
            }
        )) {
            Label {
                VStack(alignment: .leading, spacing: 3) {
                    Text(provider.title)
                        .font(TimeBiteTypography.font(.body, weight: .semibold))
                        .foregroundStyle(primaryText)
                    Text(provider.subtitle)
                        .font(TimeBiteTypography.font(.caption))
                        .foregroundStyle(secondaryText)
                }
            } icon: {
                Image(systemName: provider.icon)
                    .foregroundStyle(provider.tint)
                    .frame(width: 28)
            }
        }
        .padding(16)
    }

    private func onboardingTitle(icon: String, title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 25, weight: .semibold))
                .foregroundStyle(TimeBitePalette.teal)
            Text(title)
                .font(TimeBiteTypography.font(.largeTitle, weight: .bold))
                .foregroundStyle(primaryText)
            Text(subtitle)
                .font(TimeBiteTypography.font(.body))
                .foregroundStyle(secondaryText)
        }
    }

    private func primaryButton(_ title: String, loading: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Group {
                if loading { ProgressView().tint(.white) }
                else { Text(title).font(TimeBiteTypography.font(.body, weight: .semibold)) }
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 52)
            .foregroundStyle(.white)
            .background(TimeBitePalette.accentFill, in: Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(loading)
    }

    private func legend(color: Color, title: String, value: String) -> some View {
        HStack(spacing: 8) {
            Circle().fill(color).frame(width: 9, height: 9)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(TimeBiteTypography.font(.caption, weight: .semibold))
                Text(value).font(TimeBiteTypography.font(.caption)).foregroundStyle(secondaryText)
            }
        }
        .foregroundStyle(primaryText)
    }

    @MainActor
    private func connectCalendars() async {
        isLoading = true
        defer { isLoading = false }
        for provider in TimeBiteCalendarProvider.allCases {
            UserDefaults.standard.set(calendarSelection.contains(provider), forKey: provider.defaultsKey)
        }
        guard !calendarSelection.isEmpty else {
            step = .health
            return
        }
        do {
            let granted: Bool
            if #available(iOS 17.0, *) {
                granted = try await eventStore.requestFullAccessToEvents()
            } else {
                granted = try await withCheckedThrowingContinuation { continuation in
                    eventStore.requestAccess(to: .event) { allowed, error in
                        if let error { continuation.resume(throwing: error) }
                        else { continuation.resume(returning: allowed) }
                    }
                }
            }
            guard granted else {
                errorMessage = "Calendar access was not granted. You can continue and connect it later."
                step = .health
                return
            }
            calendarEntries = loadCalendarEntries()
            step = .health
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func connectHealth() async {
        isLoading = true
        defer { isLoading = false }
        guard healthProvider.isAvailable else {
            errorMessage = "Health data is not available on this device."
            return
        }
        do {
            try await healthProvider.requestAuthorization()
            UserDefaults.standard.set(true, forKey: "timebite.health.authorizationRequested.v1")
            let interval = Calendar.current.dateInterval(of: .day, for: Date()) ?? DateInterval(start: Date(), duration: 86_400)
            healthRecords = try await healthProvider.fetchActivity(for: interval)
            if healthRecords.isEmpty && calendarEntries.isEmpty { onComplete() }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadCalendarEntries() -> [TodayActivityEntry] {
        let day = Calendar.current.dateInterval(of: .day, for: Date()) ?? DateInterval(start: Date(), duration: 86_400)
        let selectedCalendars = eventStore.calendars(for: .event).filter { calendar in
            calendarSelection.contains { $0.matches(calendar) }
        }
        let events = eventStore.events(matching: eventStore.predicateForEvents(
            withStart: day.start,
            end: day.end,
            calendars: selectedCalendars
        ))
        return events.filter { !$0.isAllDay }.map { event in
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

    private var previewSummary: TodayActivitySummary {
        TodayActivitySummary.calculate(
            actions: [],
            sessions: [],
            healthRecords: healthRecords,
            calendarEntries: calendarEntries,
            at: Date()
        )
    }

    private var calendarDuration: TimeInterval {
        previewSummary.entries.filter { $0.source == .calendar }.reduce(0) { $0 + $1.duration }
    }

    private var healthDuration: TimeInterval {
        previewSummary.entries.filter { $0.source == .health }.reduce(0) { $0 + $1.duration }
    }

    private var surface: Color { TimeBitePalette.surface(for: colorScheme) }
    private var primaryText: Color { TimeBitePalette.primaryText(for: colorScheme) }
    private var secondaryText: Color { TimeBitePalette.secondaryText(for: colorScheme) }
    private var border: Color { TimeBitePalette.border(for: colorScheme) }

    private func durationLabel(_ seconds: TimeInterval) -> String {
        let minutes = max(0, Int(seconds / 60))
        return minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes)m"
    }

    private func continueWithEmail() {
        let trimmed = emailAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isValidEmail(trimmed) else {
            errorMessage = "Enter a valid email address to continue."
            return
        }
        emailAddress = trimmed
        UserDefaults.standard.set(trimmed, forKey: "timebite.manual.email.v1")
        UserDefaults.standard.removeObject(forKey: "timebite.apple.userID.v1")
        appleUserID = nil
        step = .calendar
    }

    private func isValidEmail(_ value: String) -> Bool {
        let parts = value.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2, let local = parts.first, let domain = parts.last else { return false }
        return !local.isEmpty && domain.contains(".") && !domain.hasPrefix(".") && !domain.hasSuffix(".")
    }

    private func handleAppleSignInError(_ error: Error) {
        guard let authorizationError = error as? ASAuthorizationError else {
            errorMessage = error.localizedDescription
            return
        }
        switch authorizationError.code {
        case .canceled:
            break
        case .notHandled:
            errorMessage = "Apple couldn't start sign-in. Confirm an Apple Account is signed in on this device and try again."
        case .failed, .invalidResponse:
            errorMessage = "Apple sign-in could not be completed. Check the app's Signing & Capabilities settings and your Apple Account."
        case .unknown:
            let error = authorizationError as NSError
            errorMessage = "Apple couldn't complete sign-in (error \(error.code)). Please try again, or continue with email."
        default:
            errorMessage = authorizationError.localizedDescription
        }
    }
}

private struct SourceActivityRingView: View {
    let calendarProgress: Double
    let healthProgress: Double
    let label: String

    var body: some View {
        ZStack {
            Circle().stroke(Color.secondary.opacity(0.14), lineWidth: 17)
            segment(from: 0, length: calendarProgress, color: TimeBitePalette.sky)
            segment(from: calendarProgress, length: healthProgress, color: TimeBitePalette.violet)
            VStack(spacing: 4) {
                Text(label)
                    .font(TimeBiteTypography.font(.title2, weight: .bold))
                Text("already mapped")
                    .font(TimeBiteTypography.font(.caption))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) of today already mapped")
    }

    private func segment(from start: Double, length: Double, color: Color) -> some View {
        Circle()
            .trim(from: min(1, max(0, start)), to: min(1, max(0, start + length)))
            .stroke(color, style: StrokeStyle(lineWidth: 17, lineCap: .round))
            .rotationEffect(.degrees(-90))
    }
}
#endif
