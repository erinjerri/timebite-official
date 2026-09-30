import Foundation
import TimeBiteCore

#if canImport(HealthKit) && os(iOS)
import HealthKit

public final class HealthKitActivityProvider: HealthActivityProvider {
    private let store: HKHealthStore

    public init(store: HKHealthStore = HKHealthStore()) {
        self.store = store
    }

    public var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    public func requestAuthorization() async throws {
        guard isAvailable else { throw HealthActivityProviderError.unavailable }
        let readTypes = try Self.readTypes()
        try await store.requestAuthorization(toShare: [], read: readTypes)
    }

    public func fetchActivity(for interval: DateInterval) async throws -> [HealthActivityRecord] {
        guard isAvailable else { throw HealthActivityProviderError.unavailable }
        async let sleep = fetchSleep(for: interval)
        async let workouts = fetchWorkouts(for: interval)
        async let mindfulness = fetchMindfulness(for: interval)
        return try await (sleep + workouts + mindfulness).deduplicatedByExternalIdentifier()
    }

    private static func readTypes() throws -> Set<HKObjectType> {
        guard let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis),
              let mindful = HKObjectType.categoryType(forIdentifier: .mindfulSession) else {
            throw HealthActivityProviderError.healthDataTypeUnavailable
        }
        return [sleep, HKWorkoutType.workoutType(), mindful]
    }

    private func fetchSleep(for interval: DateInterval) async throws -> [HealthActivityRecord] {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            throw HealthActivityProviderError.healthDataTypeUnavailable
        }
        let samples: [HKCategorySample] = try await fetchSamples(type: sleepType, interval: interval)
        let mapped = samples.map {
            SleepIntervalSample(startDate: $0.startDate, endDate: $0.endDate, isAsleep: Self.isAsleepValue($0.value))
        }
        return SleepIntervalAggregator.asleepIntervals(from: mapped, in: interval).map { asleep in
            HealthActivityRecord(
                externalIdentifier: "healthkit:sleep:\(Int(asleep.start.timeIntervalSince1970)):\(Int(asleep.end.timeIntervalSince1970))",
                type: .sleep,
                title: "Sleep",
                startDate: asleep.start,
                endDate: asleep.end
            )
        }
    }

    private func fetchWorkouts(for interval: DateInterval) async throws -> [HealthActivityRecord] {
        let workouts: [HKWorkout] = try await fetchSamples(type: HKWorkoutType.workoutType(), interval: interval)
        return workouts.compactMap { workout in
            let clamped = DateInterval(start: workout.startDate, end: workout.endDate).clamped(to: interval)
            guard clamped.duration > 0 else { return nil }
            return HealthActivityRecord(
                externalIdentifier: "healthkit:workout:\(workout.uuid.uuidString)",
                type: .workout,
                title: Self.workoutTitle(for: workout.workoutActivityType),
                startDate: clamped.start,
                endDate: clamped.end
            )
        }
    }

    private func fetchMindfulness(for interval: DateInterval) async throws -> [HealthActivityRecord] {
        guard let mindfulType = HKObjectType.categoryType(forIdentifier: .mindfulSession) else { return [] }
        let samples: [HKCategorySample] = try await fetchSamples(type: mindfulType, interval: interval)
        return samples.compactMap { sample in
            let clamped = DateInterval(start: sample.startDate, end: sample.endDate).clamped(to: interval)
            guard clamped.duration > 0 else { return nil }
            return HealthActivityRecord(
                externalIdentifier: "healthkit:mindfulness:\(sample.uuid.uuidString)",
                type: .mindfulness,
                title: "Mindfulness",
                startDate: clamped.start,
                endDate: clamped.end
            )
        }
    }

    private func fetchSamples<Sample: HKSample>(
        type: HKSampleType,
        interval: DateInterval
    ) async throws -> [Sample] {
        try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(
                withStart: interval.start,
                end: interval.end,
                options: []
            )
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: (samples as? [Sample]) ?? [])
                }
            }
            store.execute(query)
        }
    }

    private static func isAsleepValue(_ value: Int) -> Bool {
        if #available(iOS 16.0, *) {
            return value == HKCategoryValueSleepAnalysis.asleepCore.rawValue
                || value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue
                || value == HKCategoryValueSleepAnalysis.asleepREM.rawValue
                || value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue
        }
        return false
    }

    private static func workoutTitle(for activityType: HKWorkoutActivityType) -> String {
        switch activityType {
        case .walking: return "Walking"
        case .running: return "Running"
        case .traditionalStrengthTraining: return "Traditional Strength Training"
        case .cycling: return "Cycling"
        case .yoga: return "Yoga"
        case .swimming: return "Swimming"
        case .hiking: return "Hiking"
        case .dance: return "Dance"
        case .pilates: return "Pilates"
        case .mindAndBody: return "Mind and Body"
        default: return "Workout"
        }
    }
}
#else
public final class HealthKitActivityProvider: HealthActivityProvider {
    public init() {}

    public var isAvailable: Bool { false }

    public func requestAuthorization() async throws {
        throw HealthActivityProviderError.unsupportedPlatform
    }

    public func fetchActivity(for interval: DateInterval) async throws -> [HealthActivityRecord] {
        throw HealthActivityProviderError.unsupportedPlatform
    }
}
#endif
