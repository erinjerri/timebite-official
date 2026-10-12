import SwiftUI
import TimeBiteCore

struct HairlineDivider: View {
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        Rectangle().fill(TimeBitePalette.secondaryText(for: scheme))
            .frame(height: 1 / max(1, displayScale)).accessibilityHidden(true)
    }
    @Environment(\.displayScale) private var displayScale
}

struct Masthead: View {
    let title: String
    let subtitle: String
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HairlineDivider()
            HairlineDivider()
            Text(Date.now, format: .dateTime.weekday(.wide).month(.wide).day())
                .textCase(.uppercase)
                .font(TimeBiteTypography.font(.caption)).tracking(2)
            Text(title).font(TimeBiteTypography.font(.largeTitle))
            Text(subtitle).font(TimeBiteTypography.font(.caption)).tracking(2)
                .foregroundStyle(TimeBitePalette.secondaryText(for: scheme))
        }
        .foregroundStyle(TimeBitePalette.primaryText(for: scheme))
    }
}

struct SquareTile<Content: View>: View {
    @Environment(\.colorScheme) private var scheme
    let kicker: String
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HairlineDivider()
            Text(kicker.uppercased()).font(TimeBiteTypography.font(.caption)).tracking(2)
                .foregroundStyle(TimeBitePalette.secondaryText(for: scheme))
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(TimeBitePalette.surface(for: scheme))
    }
}

struct AdaptiveRow<Content: View>: View {
    @Environment(\.dynamicTypeSize) private var size
    @ViewBuilder var content: Content
    var body: some View {
        if size.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 16) { content }
        } else {
            HStack(alignment: .center, spacing: 16) { content }
        }
    }
}

struct StagePips: View {
    let stage: Int
    let total: Int
    let title: String
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        AdaptiveRow {
            HStack(spacing: 8) {
                ForEach(0..<max(0, total), id: \.self) { index in
                    Rectangle()
                        .fill(index < stage - 1 ? TimeBitePalette.primaryText(for: scheme) : .clear)
                        .overlay(Rectangle().stroke(TimeBitePalette.primaryText(for: scheme),
                            style: StrokeStyle(lineWidth: 1, dash: index >= stage ? [2, 2] : [])))
                        .frame(width: 12, height: 12)
                }
            }
            Text(title.uppercased()).font(TimeBiteTypography.font(.caption)).tracking(2)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Stage \(stage) of \(total), \(title)")
    }
}

#if os(iOS)
struct TimeBiteTabsView: View {
    @StateObject private var activity = ActivityLoopController()
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        TabView {
            TimeBiteTodayView(activity: activity)
                .tabItem { Label("Actions", systemImage: "timer") }
            goals.tabItem { Label("Goals", systemImage: "target") }
            track.tabItem { Label("Track", systemImage: "chart.xyaxis.line") }
            reflection.tabItem { Label("Reflect", systemImage: "checklist") }
        }
        .tint(TimeBitePalette.teal)
        .safeAreaInset(edge: .top, spacing: 0) {
            if let session = activity.currentSession, session.status == .running,
               let action = activity.currentAction {
                TimerChip(activity: activity, session: session, title: action.title)
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .background(TimeBitePalette.background(for: scheme))
            }
        }
    }

    private func screen<Content: View>(_ title: String, subtitle: String,
                                      @ViewBuilder content: () -> Content) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Masthead(title: title, subtitle: subtitle)
                content()
            }
            .frame(maxWidth: 720).padding(24).frame(maxWidth: .infinity)
        }
        .foregroundStyle(TimeBitePalette.primaryText(for: scheme))
        .background(TimeBitePalette.background(for: scheme).ignoresSafeArea())
    }

    private var goals: some View {
        screen("Keep the destination in view.", subtitle: "GOALS / PROJECTS") {
            if activity.snapshot.goals.isEmpty && activity.snapshot.projects.isEmpty {
                SquareTile(kicker: "Your altitude") {
                    Text("Start with a plan.").font(TimeBiteTypography.font(.title2))
                    Text("Scan a paper plan from Actions to bring your goals, projects and tasks together.")
                }
            }
            ForEach(activity.snapshot.goals) { goal in
                SquareTile(kicker: "Goal · \(goal.status.rawValue)") {
                    Text(goal.title).font(TimeBiteTypography.font(.title2))
                    ForEach(activity.snapshot.projects.filter { $0.goalID == goal.id }) { project in
                        projectRow(project)
                    }
                }
            }
            ForEach(activity.snapshot.projects.filter { project in project.goalID == nil || !activity.snapshot.goals.contains(where: { $0.id == project.goalID }) }) { project in
                SquareTile(kicker: "Project") { projectRow(project) }
            }
        }
    }

    private func projectRow(_ project: Project) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HairlineDivider()
            Text(project.title).font(TimeBiteTypography.font(.headline))
            ForEach(activity.snapshot.actions.filter { $0.projectID == project.id }) { action in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: action.executionState == .completed ? "checkmark.square.fill" : "square")
                    VStack(alignment: .leading, spacing: 4) {
                        Text(action.title)
                        Text(action.executionState.rawValue).font(TimeBiteTypography.font(.caption))
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    private var track: some View {
        screen("A clearer picture of today.", subtitle: "TRACK / ACTIVITY") {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let summary = activity.todaySummary(at: context.date)
                SquareTile(kicker: "Tracked day") {
                    ActivityRingView(progress: summary.trackedDayProgress,
                        label: duration(summary.trackedDuration), secondaryLabel: "of \(duration(summary.dayInterval.duration)) today",
                        accentColor: TimeBitePalette.teal, lineWidth: 16)
                        .frame(width: 220, height: 220).frame(maxWidth: .infinity)
                    Text("Calendar, Health and TimeBite intervals, with overlaps counted once.")
                        .font(TimeBiteTypography.font(.caption))
                }
                SquareTile(kicker: "Activity ledger") {
                    if summary.entries.isEmpty { Text("Your tracked activities will appear here.") }
                    ForEach(summary.entries) { entry in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(entry.title).font(TimeBiteTypography.font(.headline))
                            Text("\(entry.source.rawValue) · \(duration(entry.duration))")
                                .font(TimeBiteTypography.font(.caption)).monospacedDigit()
                            HairlineDivider()
                        }
                    }
                }
            }
        }
    }

    private var reflection: some View {
        screen("Make room to reflect.", subtitle: "REFLECT / DAILY REVIEW") {
            SquareTile(kicker: "A moment to pause") {
                Text("What deserved your time today?").font(TimeBiteTypography.font(.title2))
                Text("Review your activity in Track, then consider what to carry into tomorrow.")
                HairlineDivider()
                Text("Saved reflections are not available in this build.")
                    .font(TimeBiteTypography.font(.caption))
            }
        }
    }

    private func duration(_ seconds: TimeInterval) -> String {
        let minutes = max(0, Int(seconds / 60))
        return "\(minutes / 60)h \(minutes % 60)m"
    }
}

struct TimeBlockRow: View {
    let action: Action
    @ObservedObject var activity: ActivityLoopController
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let sessions = activity.snapshot.sessions.filter { $0.actionID == action.id }
            let elapsed = sessions.reduce(0.0) { $0 + $1.elapsed(at: context.date) }
            let planned = max(0, action.plannedDuration ?? 0)
            VStack(alignment: .leading, spacing: 12) {
                AdaptiveRow {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(action.title).font(TimeBiteTypography.font(.headline))
                        if let goal = activity.snapshot.goals.first(where: { $0.id == action.goalID }) {
                            Text(goal.title.uppercased()).font(TimeBiteTypography.font(.caption)).tracking(1)
                        }
                        Text("\(Int(elapsed / 60))m executed / \(Int(planned / 60))m planned")
                            .font(TimeBiteTypography.font(.caption)).monospacedDigit()
                        Text(action.executionState.rawValue).font(TimeBiteTypography.font(.caption))
                    }
                    Spacer(minLength: 0)
                    if action.executionState == .notStarted {
                        Button("Start") { activity.start(action) }
                            .frame(minWidth: 44, minHeight: 44)
                            .disabled(activity.currentSession != nil)
                    } else if activity.currentAction?.id == action.id {
                        Button(activity.currentSession?.status == .running ? "Pause" : "Resume") {
                            if activity.currentSession?.status == .running { activity.pause() }
                            else { activity.resume() }
                        }.frame(minWidth: 44, minHeight: 44)
                    }
                }
                GeometryReader { proxy in
                    Rectangle().fill(TimeBitePalette.border(for: scheme))
                        .overlay(alignment: .leading) {
                            Rectangle().fill(TimeBitePalette.teal)
                                .frame(width: proxy.size.width * (planned > 0 ? min(1, elapsed / planned) : 0))
                        }
                }.frame(height: 4).accessibilityHidden(true)
                if elapsed > planned && planned > 0 {
                    Text("• Over plan by \(Int((elapsed - planned) / 60))m")
                        .font(TimeBiteTypography.font(.caption))
                }
                HairlineDivider()
            }
            .padding(12)
            .background(TimeBitePalette.elevatedSurface(for: scheme))
        }
    }
}

struct TimerChip: View {
    @ObservedObject var activity: ActivityLoopController
    let session: ActivitySession
    let title: String
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            AdaptiveRow {
                VStack(alignment: .leading, spacing: 4) {
                    Text("RUNNING / \(title)").font(TimeBiteTypography.font(.caption))
                    Text(elapsed(at: context.date)).font(.body).monospacedDigit()
                }
                Spacer(minLength: 0)
                Button("Stop") { activity.complete() }
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityLabel("Stop and complete \(title)")
            }
            .padding(.horizontal, 24).padding(.vertical, 8)
            .foregroundStyle(.white).tint(.white)
            .background(TimeBitePalette.accentFill, in: Capsule())
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Running timer for \(title), \(elapsed(at: context.date))")
        }
    }
    private func elapsed(at date: Date) -> String {
        let seconds = max(0, Int(session.elapsed(at: date)))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}
#endif

struct TimeBiteDesignSystem_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 24) {
            Masthead(title: "Make time count.", subtitle: "TODAY / TIMEBITE")
            StagePips(stage: 2, total: 3, title: "Calendar")
            SquareTile(kicker: "Focus") { Text("One action at a time.").font(TimeBiteTypography.font(.title2)) }
        }.padding(24)
    }
}
