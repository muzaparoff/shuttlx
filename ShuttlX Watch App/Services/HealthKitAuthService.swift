import Foundation
import HealthKit
import ShuttlXShared
import os.log

/// HealthKit authorization for the watch workout flow — extracted from
/// WatchWorkoutManager (refactor plan Phase 3). Owns the request/timeout logic
/// and the age→max-HR bootstrap; the manager reflects the result into its
/// @Published flags.
@MainActor
final class HealthKitAuthService {

    struct AuthResult {
        let authorized: Bool
        let denied: Bool
    }

    private let healthStore: HKHealthStore
    private let logger = Logger(subsystem: "com.shuttlx.ShuttlX.watchkitapp", category: "HealthKitAuth")

    /// Deadline for `HKHealthStore.requestAuthorization`. Sized for a first-ever
    /// launch, where the call blocks on the user reading the multi-toggle grant sheet.
    static let authTimeoutSeconds: TimeInterval = 30
    private static var authTimeoutNanoseconds: UInt64 { UInt64(authTimeoutSeconds * 1_000_000_000) }

    init(healthStore: HKHealthStore) {
        self.healthStore = healthStore
    }

    /// Async, awaitable authorization request.
    /// Uses the fast-path `authorizationStatus` check to avoid showing the sheet on repeat launches.
    func requestAuthorization() async -> AuthResult {
        // Fast path: check current status without presenting the sheet again.
        // On watchOS, HKAuthorizationStatus is not queryable per-type the same way as iOS,
        // so we always call requestAuthorization — it is a no-op if already granted.
        let (readTypes, writeTypes) = buildHealthKitTypes()

        // Include date of birth for age-based HR zone calculation (Tanaka formula)
        var allReadTypes: Set<HKObjectType> = Set(readTypes)
        if let dobType = HKCharacteristicType.characteristicType(forIdentifier: .dateOfBirth) {
            allReadTypes.insert(dobType)
        }

        guard !readTypes.isEmpty else {
            logger.error("No valid HealthKit types available for authorization")
            return AuthResult(authorized: false, denied: true)
        }

        // Timeout guards against HKHealthStore.requestAuthorization hanging
        // indefinitely (observed when the HealthKit daemon is in a bad state on watch).
        // Without this, isStarting stays true and the UI appears completely frozen.
        //
        // 30s, not 8s: on a first-ever launch this call presents the multi-toggle
        // grant sheet, and the user reads it. Eight seconds routinely expired while
        // the sheet was still on screen.
        do {
            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask {
                    try await self.healthStore.requestAuthorization(toShare: writeTypes, read: allReadTypes)
                }
                group.addTask {
                    try await Task.sleep(nanoseconds: Self.authTimeoutNanoseconds)
                    throw CancellationError()
                }
                try await group.next()
                group.cancelAll()
            }
            logger.info("HealthKit authorization granted")
            updateMaxHRFromHealthKit()
            return AuthResult(authorized: true, denied: false)
        } catch {
            if error is CancellationError {
                // NOT authorized. This previously returned authorized:true ("proceed
                // without full auth"), which let a workout start with no confirmed
                // HealthKit grant: the HKWorkoutSession then behaves unpredictably —
                // it can be torn down by the system moments later. denied stays false
                // because nothing was actually refused; the caller distinguishes the
                // two and surfaces a retry prompt.
                logger.error("HealthKit authorization timed out after \(Int(Self.authTimeoutSeconds))s — treating as NOT authorized")
                return AuthResult(authorized: false, denied: false)
            } else {
                logger.error("HealthKit authorization error: \(error.localizedDescription)")
                return AuthResult(authorized: false, denied: true)
            }
        }
    }

    private func buildHealthKitTypes() -> (read: Set<HKQuantityType>, write: Set<HKSampleType>) {
        var readTypes = Set<HKQuantityType>()
        var writeTypes = Set<HKSampleType>()

        if let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) {
            readTypes.insert(heartRateType)
        }
        if let activeEnergyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
            readTypes.insert(activeEnergyType)
            writeTypes.insert(activeEnergyType)
        }
        if let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) {
            readTypes.insert(distanceType)
            writeTypes.insert(distanceType)
        }
        if let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) {
            readTypes.insert(stepType)
        }

        writeTypes.insert(HKWorkoutType.workoutType())
        return (readTypes, writeTypes)
    }

    /// Reads date of birth from HealthKit and persists the Tanaka-derived max HR
    /// to the App Group UserDefaults. A manual override stored there is not clobbered —
    /// the UI max HR field takes precedence over the formula.
    private func updateMaxHRFromHealthKit() {
        // Only update from HealthKit when no manual override exists
        guard HeartRateZoneCalculator.loadSavedMaxHR() == nil else {
            logger.info("Manual max HR override present — skipping HealthKit age lookup")
            return
        }

        do {
            let components = try healthStore.dateOfBirthComponents()
            let calendar = Calendar.current
            let now = calendar.dateComponents([.year], from: Date())
            guard let birthYear = components.year, let currentYear = now.year else { return }
            let age = currentYear - birthYear
            guard age > 0, age < 120 else { return }

            let calculator = HeartRateZoneCalculator(age: age, manualMaxHR: nil)
            HeartRateZoneCalculator.saveMaxHR(calculator.estimatedMaxHR)
            logger.info("Max HR updated from HealthKit age \(age): \(calculator.estimatedMaxHR) BPM")
        } catch {
            logger.info("Date of birth not available in HealthKit: \(error.localizedDescription)")
        }
    }
}
