import SwiftUI
import TimeBiteCore

/// Keeps the platform's original AM / PM / total color meanings.
struct TrackedDayRingView: View {
    let summary: TodayActivitySummary
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var size
    @Environment(\.colorScheme) private var scheme

    private var noon: Date {
        Calendar.current.date(bySettingHour: 12, minute: 0, second: 0,
                              of: summary.dayInterval.start) ?? summary.dayInterval.start.addingTimeInterval(summary.dayInterval.duration / 2)
    }
    private var morning: DateInterval { DateInterval(start: summary.dayInterval.start, end: noon) }
    private var evening: DateInterval { DateInterval(start: noon, end: summary.dayInterval.end) }
    private func tracked(in interval: DateInterval) -> TimeInterval {
        IntervalAggregation.mergedDuration(summary.entries.compactMap(\.occupiedInterval).map { $0.clamped(to: interval) })
    }

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                band(progress: summary.trackedDayProgress, color: TimeBitePalette.totalRingColor, inset: 0)
                band(progress: morning.duration > 0 ? tracked(in: morning) / morning.duration : 0,
                     color: TimeBitePalette.amRingColor, inset: 20)
                band(progress: evening.duration > 0 ? tracked(in: evening) / evening.duration : 0,
                     color: TimeBitePalette.pmRingColor, inset: 40)
                if !size.isAccessibilitySize { center }
            }
            .frame(width: 248, height: 248)
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Today: \(duration(summary.trackedDuration)) tracked of \(duration(summary.dayInterval.duration)). Morning \(duration(tracked(in: morning))) of \(duration(morning.duration)). Afternoon and evening \(duration(tracked(in: evening))) of \(duration(evening.duration)).")
            if size.isAccessibilitySize { center }
            VStack(spacing: 8) {
                legend("Total", value: summary.trackedDuration, budget: summary.dayInterval.duration, color: TimeBitePalette.totalRingColor)
                legend("AM", value: tracked(in: morning), budget: morning.duration, color: TimeBitePalette.amRingColor)
                legend("PM", value: tracked(in: evening), budget: evening.duration, color: TimeBitePalette.pmRingColor)
            }
        }
    }

    private var center: some View {
        VStack(spacing: 4) {
            Text("\(duration(summary.trackedDuration)) tracked")
                .font(TimeBiteTypography.font(.headline)).monospacedDigit()
            Text("\(Int((summary.trackedDayProgress * 100).rounded()))% of today")
                .font(TimeBiteTypography.font(.caption))
                .foregroundStyle(TimeBitePalette.secondaryText(for: scheme))
        }.multilineTextAlignment(.center).padding(12)
    }

    private func band(progress: Double, color: Color, inset: CGFloat) -> some View {
        ZStack {
            Circle().stroke(color.opacity(0.24), lineWidth: 12)
            Circle().trim(from: 0, to: min(1, max(0, progress)))
                .stroke(color, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: progress)
        }.padding(inset + 6)
    }

    private func legend(_ title: String, value: TimeInterval, budget: TimeInterval, color: Color) -> some View {
        AdaptiveRow {
            HStack(spacing: 8) {
                Rectangle().fill(color).frame(width: 10, height: 10)
                Text(title).font(TimeBiteTypography.font(.caption))
            }
            Text("\(duration(value)) / \(duration(budget))")
                .font(TimeBiteTypography.font(.caption)).monospacedDigit()
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private func duration(_ seconds: TimeInterval) -> String {
        let minutes = max(0, Int(seconds / 60))
        return minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes)m"
    }
}
