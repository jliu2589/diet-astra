import Foundation
import HealthKit

struct HealthWorkout: Identifiable {
    let id: UUID
    let date: Date
    let title: String
    let duration: TimeInterval
    let source: String
}

struct HealthSnapshot {
    var weights: [WeightProgress.Point] = []
    var steps: [String: Int] = [:]
    var activeCalories: [String: Double] = [:]
    var exerciseMinutes: [String: Double] = [:]
    var workouts: [HealthWorkout] = []
    var workoutCounts: [String: Int] {
        Dictionary(grouping: workouts) { DayKey.string($0.date) }.mapValues(\.count)
    }
}

@MainActor
final class HealthService {
    private let store = HKHealthStore()
    static var available: Bool { HKHealthStore.isHealthDataAvailable() }

    func read(requestPermission: Bool) async throws -> HealthSnapshot {
        guard Self.available else { throw AppFailure.unavailable }
        let weight = HKQuantityType(.bodyMass), steps = HKQuantityType(.stepCount)
        let energy = HKQuantityType(.activeEnergyBurned), exercise = HKQuantityType(.appleExerciseTime)
        if requestPermission {
            try await store.requestAuthorization(toShare: [], read: [weight, steps, energy, exercise, HKObjectType.workoutType()])
        }
        // Capture one window for every query, using calendar days rather than 24-hour offsets.
        let calendar = Calendar.astra
        let end = Date.now
        let start = calendar.startOfDay(for: calendar.date(byAdding: .year, value: -1, to: end)!)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let weights = try await samples(weight, predicate: predicate).compactMap { $0 as? HKQuantitySample }
        let workouts = try await samples(HKObjectType.workoutType(), predicate: predicate).compactMap { $0 as? HKWorkout }
        let dailySteps = try await dailyTotals(steps, unit: .count(), start: start, end: end)
        let dailyEnergy = try await dailyTotals(energy, unit: .kilocalorie(), start: start, end: end)
        let dailyExercise = try await dailyTotals(exercise, unit: .minute(), start: start, end: end)
        return HealthSnapshot(
            weights: weights.map { .init(date: $0.startDate, pounds: $0.quantity.doubleValue(for: .pound())) },
            steps: dailySteps.mapValues { Int($0.rounded()) },
            activeCalories: dailyEnergy, exerciseMinutes: dailyExercise,
            workouts: workouts.map { HealthWorkout(id: $0.uuid, date: $0.startDate,
                title: Self.title($0.workoutActivityType), duration: $0.duration, source: $0.sourceRevision.source.name) }
                .sorted { $0.date > $1.date })
    }

    private func dailyTotals(_ type: HKQuantityType, unit: HKUnit, start: Date, end: Date) async throws -> [String: Double] {
        let calendar = Calendar.astra
        return try await withCheckedThrowingContinuation { continuation in
            // HealthKit aggregates overlapping sources; never sum raw phone/watch samples ourselves.
            let query = HKStatisticsCollectionQuery(quantityType: type,
                quantitySamplePredicate: HKQuery.predicateForSamples(withStart: start, end: end),
                options: .cumulativeSum, anchorDate: start, intervalComponents: DateComponents(day: 1))
            query.initialResultsHandler = { _, collection, error in
                if let error { continuation.resume(throwing: error); return }
                var values: [String: Double] = [:]
                collection?.enumerateStatistics(from: start, to: end) { statistics, _ in
                    if let value = statistics.sumQuantity()?.doubleValue(for: unit), value.isFinite, value >= 0 {
                        values[DayKey.string(statistics.startDate, calendar: calendar)] = value
                    }
                }
                continuation.resume(returning: values)
            }
            store.execute(query)
        }
    }

    private func samples(_ type: HKSampleType, predicate: NSPredicate) async throws -> [HKSample] {
        try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                if let error { continuation.resume(throwing: error) } else { continuation.resume(returning: samples ?? []) }
            }
            store.execute(query)
        }
    }

    private static func title(_ type: HKWorkoutActivityType) -> String {
        switch type {
        case .walking: "Walking"
        case .running: "Running"
        case .cycling: "Cycling"
        case .swimming: "Swimming"
        case .hiking: "Hiking"
        case .traditionalStrengthTraining: "Strength training"
        case .functionalStrengthTraining: "Functional strength"
        case .highIntensityIntervalTraining: "HIIT"
        case .yoga: "Yoga"
        case .pilates: "Pilates"
        case .elliptical: "Elliptical"
        case .rowing: "Rowing"
        case .stairClimbing, .stairs: "Stairs"
        case .dance, .cardioDance, .socialDance: "Dance"
        case .coreTraining: "Core training"
        case .cooldown: "Cooldown"
        case .mixedCardio: "Mixed cardio"
        case .soccer: "Soccer"
        case .basketball: "Basketball"
        case .tennis: "Tennis"
        default: "Workout"
        }
    }
}
