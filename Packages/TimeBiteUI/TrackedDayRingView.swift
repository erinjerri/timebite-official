import SwiftUI
import TimeBiteCore
import TimeBiteData

/// Life-area colors from timebite-platform's LifeAreaCatalog.
enum RingCategory {
    static let areas = ["Faith", "Fitness/Health", "Finance", "Fun", "Family", "Friends", "Work"]
    static func color(_ area: String) -> Color {
        switch area {
        case "Faith": return Color(red: 0.70, green: 0.53, blue: 0.98)
        case "Fitness/Health": return TimeBitePalette.gold
        case "Finance": return Color(red: 0.34, green: 0.82, blue: 0.62)
        case "Fun": return Color(red: 0.98, green: 0.52, blue: 0.38)
        case "Family": return Color(red: 0.92, green: 0.47, blue: 0.82)
        case "Friends": return Color(red: 0.39, green: 0.77, blue: 0.98)
        case "Work": return TimeBitePalette.teal
        default: return .gray
        }
    }
    static func category(_ entry: TodayActivityEntry, snapshot: ActivitySnapshot) -> String {
        if entry.source == .health { return "Fitness/Health" }
        guard let action = snapshot.actions.first(where: { "timebite:\($0.id.uuidString)" == entry.id }) else { return "Uncategorized" }
        let project = snapshot.projects.first { $0.id == action.projectID }
        let goal = snapshot.goals.first { $0.id == (action.goalID ?? project?.goalID) }
        return goal?.lifeArea ?? "Uncategorized"
    }
}

struct TrackedDayRingView: View {
    let summary: TodayActivitySummary
    let snapshot: ActivitySnapshot
    let now: Date
    @Environment(\.dynamicTypeSize) private var size
    private var noon: Date {
        Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: summary.dayInterval.start) ?? summary.dayInterval.start.addingTimeInterval(summary.dayInterval.duration / 2)
    }
    @State private var selectedPeriod = "AM"
    var body: some View {
        VStack(spacing: 28) {
            Picker("Activity period", selection: $selectedPeriod) {
                Text("AM").tag("AM")
                Text("PM").tag("PM")
                Text("Total").tag("Total")
            }
            #if !os(watchOS)
            .pickerStyle(.segmented)
            #endif
            ring(selectedPeriod, interval: selectedPeriod == "AM" ? morning : selectedPeriod == "PM" ? evening : summary.dayInterval)
        }
    }
    private var morning: DateInterval { DateInterval(start: summary.dayInterval.start, end: noon) }
    private var evening: DateInterval { DateInterval(start: noon, end: summary.dayInterval.end) }

    /// Sweep disjoint time slices so overlapping sources never double-fill the ring.
    func slices(_ interval: DateInterval) -> [(String, TimeInterval)] {
        let entries = summary.entries.filter { $0.occupiedInterval != nil }
        let boundaries = Set(entries.flatMap { entry -> [Date] in
            let clipped = entry.occupiedInterval!.clamped(to: interval)
            return clipped.duration > 0 ? [clipped.start, clipped.end] : []
        }).sorted()
        guard boundaries.count > 1 else { return [] }
        var result: [(String, TimeInterval)] = []
        for index in 0..<(boundaries.count - 1) {
            let start = boundaries[index], end = boundaries[index + 1]
            // Explicit TimeBite categorization takes priority over imported sources.
            let candidates = entries.filter { $0.startDate! <= start && $0.endDate! >= end }
            guard let entry = candidates.first(where: { $0.source == .timeBite }) ?? candidates.first(where: { $0.source == .health }) ?? candidates.first else { continue }
            let category = RingCategory.category(entry, snapshot: snapshot)
            if result.last?.0 == category { result[result.count - 1].1 += end.timeIntervalSince(start) }
            else { result.append((category, end.timeIntervalSince(start))) }
        }
        return result
    }
    private func ring(_ title: String, interval: DateInterval) -> some View {
        let segments = slices(interval)
        let captured = segments.reduce(0) { $0 + $1.1 }
        let categories = Array(Set(segments.map { $0.0 })).sorted()
        return VStack(spacing: 12) {
            Text(title.uppercased()).font(TimeBiteTypography.font(.headline))
            ZStack {
                Circle().stroke(Color.gray.opacity(0.22), lineWidth: 16)
                ForEach(segments.indices, id: \.self) { index in
                    let start = segments.prefix(index).reduce(0) { $0 + $1.1 } / interval.duration
                    let end = start + segments[index].1 / interval.duration
                    Circle().trim(from: start, to: min(1, end))
                        .stroke(RingCategory.color(segments[index].0), style: StrokeStyle(lineWidth: 16, lineCap: .butt))
                        .rotationEffect(.degrees(-90))
                }
                if !size.isAccessibilitySize { label(captured, budget: interval.duration) }
            }
            .frame(width: 248, height: 248).frame(maxWidth: .infinity)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(title): \(duration(captured)) captured of \(duration(interval.duration))")
            if size.isAccessibilitySize { label(captured, budget: interval.duration) }
            ForEach(categories, id: \.self) { category in
                HStack {
                    Rectangle().fill(RingCategory.color(category)).frame(width: 10, height: 10)
                    Text(category)
                    Spacer()
                    Text(duration(segments.filter { $0.0 == category }.reduce(0) { $0 + $1.1 }))
                }.font(TimeBiteTypography.font(.caption))
            }
        }
    }
    private func label(_ seconds: TimeInterval, budget: TimeInterval) -> some View {
        VStack {
            Text("\(duration(seconds)) captured").font(TimeBiteTypography.font(.headline))
            Text("of \(duration(budget))").font(TimeBiteTypography.font(.caption))
        }.multilineTextAlignment(.center).padding(12)
    }
    private func duration(_ seconds: TimeInterval) -> String {
        let minutes = max(0, Int(seconds / 60))
        return minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes)m"
    }
}
