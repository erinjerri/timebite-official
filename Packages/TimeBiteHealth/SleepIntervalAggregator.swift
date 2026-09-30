import Foundation
import TimeBiteCore

public struct SleepIntervalSample: Equatable, Sendable {
    public let startDate: Date
    public let endDate: Date
    public let isAsleep: Bool

    public init(startDate: Date, endDate: Date, isAsleep: Bool) {
        self.startDate = startDate
        self.endDate = endDate
        self.isAsleep = isAsleep
    }
}

public enum SleepIntervalAggregator {
    public static func asleepIntervals(
        from samples: [SleepIntervalSample],
        in boundary: DateInterval
    ) -> [DateInterval] {
        let intervals = samples.compactMap { sample -> DateInterval? in
            guard sample.isAsleep, sample.endDate > sample.startDate else { return nil }
            let clamped = DateInterval(start: sample.startDate, end: sample.endDate).clamped(to: boundary)
            return clamped.duration > 0 ? clamped : nil
        }
        return merge(intervals)
    }

    public static func asleepDuration(
        from samples: [SleepIntervalSample],
        in boundary: DateInterval
    ) -> TimeInterval {
        asleepIntervals(from: samples, in: boundary).reduce(0) { $0 + $1.duration }
    }

    private static func merge(_ intervals: [DateInterval]) -> [DateInterval] {
        let sorted = intervals.sorted { $0.start < $1.start }
        guard var current = sorted.first else { return [] }
        var merged: [DateInterval] = []
        for interval in sorted.dropFirst() {
            if interval.start <= current.end {
                current = DateInterval(start: current.start, end: max(current.end, interval.end))
            } else {
                merged.append(current)
                current = interval
            }
        }
        merged.append(current)
        return merged
    }
}
