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

        // Characteristics: date of birth for age-based HR zones (Tanaka formula),
        // plus biological sex for the health profile behind per-phase calorie
        // estimation (Phase 2 / CE4 of the 2026-08 run+walk plan). `bodyMass` is a
        // quantity type and is added in buildHealthKitTypes().
        var allReadTypes: Set<HKObjectType> = Set(readTypes)
        if let dobType = HKCharacteristicType.characteristicType(forIdentifier: .dateOfBirth) {
            allReadTypes.insert(dobType)
        }
        if let sexType = HKCharacteristicType.characteristicType(forIdentifier: .biologicalSex) {
            allReadTypes.insert(sexType)
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
            updateAgeFromHealthKit()
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
        // Cycling / swimming sessions report distance through the live builder
        // only if these types are authorized (walking/running alone left them at 0).
        for identifier in [HKQuantityTypeIdentifier.distanceCycling, .distanceSwimming] {
            let type = HKQuantityType(identifier)
            readTypes.insert(type)
            writeTypes.insert(type)
        }
        if let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) {
            readTypes.insert(stepType)
        }
        // Body mass drives the MET calorie model (kcal = MET × kg × hours). Without
        // it there is no honest per-phase estimate — see loadAnthropometrics().
        if let bodyMassType = HKQuantityType.quantityType(forIdentifier: .bodyMass) {
            readTypes.insert(bodyMassType)
        }

        writeTypes.insert(HKWorkoutType.workoutType())
        // HKWorkoutRouteBuilder.finishRoute needs share access to the route series;
        // without it the GPS route never reaches Health ("Failed to finalize route").
        writeTypes.insert(HKSeriesType.workoutRoute())
        return (readTypes, writeTypes)
    }

    // MARK: - Anthropometrics (Phase 2 / CE4)

    /// App Group key iOS Settings writes when the wearer types a weight by hand
    /// (`DeviceManager.userWeightKg`). NOTE: App Group containers are per-device —
    /// the phone's value does not reach the watch today, so on watchOS this is a
    /// forward-compatible override that is normally absent and HealthKit is the
    /// real source. Kept so a future WC sync of Settings lands for free.
    private static let manualWeightKey = "userWeightKg"
    private static let manualAgeKey = "userAge"
    private static let appGroupIdentifier = "group.com.shuttlx.shared"

    /// Reads body mass, age and biological sex once per workout start.
    ///
    /// Deliberately returns a nil `weightKg` when nothing is known — the caller
    /// suppresses ShuttlX's calorie estimate and prompts for the weight instead of
    /// substituting a 70 kg stand-in (plan item 5).
    func loadAnthropometrics() async -> Anthropometrics {
        let defaults = UserDefaults(suiteName: Self.appGroupIdentifier)

        let manualWeight = defaults?.double(forKey: Self.manualWeightKey) ?? 0
        let manualAge = defaults?.integer(forKey: Self.manualAgeKey) ?? 0

        let age: Int? = manualAge > 0 ? manualAge : ageFromHealthKit()
        let weightKg: Double? = manualWeight > 0 ? manualWeight : await bodyMassFromHealthKit()

        let maxHR: Double? = {
            if let saved = HeartRateZoneCalculator.loadSavedMaxHR(), saved > 0 { return saved }
            guard let age = age else { return nil }
            return HeartRateZoneCalculator(age: age, manualMaxHR: nil).estimatedMaxHR
        }()

        let anthropometrics = Anthropometrics(
            weightKg: weightKg,
            age: age,
            maxHeartRate: maxHR,
            biologicalSex: biologicalSexFromHealthKit()
        )

        logger.info("""
            Anthropometrics: weight=\(weightKg.map { String(format: "%.1fkg", $0) } ?? "unavailable") \
            (\(manualWeight > 0 ? "manual" : "healthkit")) age=\(age.map(String.init) ?? "unavailable") \
            maxHR=\(maxHR.map { String(Int($0.rounded())) } ?? "unavailable") \
            sex=\(anthropometrics.biologicalSex.rawValue)
            """)
        return anthropometrics
    }

    private func ageFromHealthKit() -> Int? {
        do {
            let components = try healthStore.dateOfBirthComponents()
            let currentYear = Calendar.current.dateComponents([.year], from: Date()).year
            guard let birthYear = components.year, let currentYear = currentYear else { return nil }
            let age = currentYear - birthYear
            return (age > 0 && age < 120) ? age : nil
        } catch {
            logger.info("Date of birth not available: \(error.localizedDescription)")
            return nil
        }
    }

    private func biologicalSexFromHealthKit() -> Anthropometrics.BiologicalSex {
        do {
            switch try healthStore.biologicalSex().biologicalSex {
            case .female: return .female
            case .male: return .male
            case .other: return .other
            case .notSet: return .unspecified
            @unknown default: return .unspecified
            }
        } catch {
            logger.info("Biological sex not available: \(error.localizedDescription)")
            return .unspecified
        }
    }

    /// Most recent `bodyMass` sample. HealthKit never reports whether a READ scope
    /// was granted, so a denial is indistinguishable from "never weighed myself" —
    /// both land here as nil, and both want the same UI prompt.
    private func bodyMassFromHealthKit() async -> Double? {
        guard let bodyMassType = HKQuantityType.quantityType(forIdentifier: .bodyMass) else { return nil }
        let store = healthStore
        let sample: HKQuantitySample? = await withCheckedContinuation { continuation in
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
            let query = HKSampleQuery(sampleType: bodyMassType,
                                      predicate: nil,
                                      limit: 1,
                                      sortDescriptors: [sort]) { _, samples, _ in
                continuation.resume(returning: samples?.first as? HKQuantitySample)
            }
            store.execute(query)
        }
        guard let sample = sample else { return nil }
        let kg = sample.quantity.doubleValue(for: .gramUnit(with: .kilo))
        return kg > 0 ? kg : nil
    }

    /// Reads date of birth from HealthKit and stores the AGE in the App Group
    /// (`userAge`, read by `HeartRateZoneCalculator.fromSharedDefaults`), same rule
    /// as the phone: `userMaxHeartRate` holds only a value the user typed (synced as
    /// `maxHR`), so the estimate follows the age instead of being frozen.
    private func updateAgeFromHealthKit() {
        do {
            let c = try healthStore.dateOfBirthComponents()
            guard let year = c.year,
                  let age = HeartLimits.age(birthYear: year, birthMonth: c.month, birthDay: c.day, now: Date()) else { return }
            UserDefaults(suiteName: Self.appGroupIdentifier)?.set(age, forKey: Self.manualAgeKey)
            // Older builds froze the Tanaka estimate (year-only age, then or a year
            // ago) into the override key. Drop it when it is exactly that number.
            let currentYear = Calendar.current.component(.year, from: Date())
            if let saved = HeartRateZoneCalculator.loadSavedMaxHR(),
               [0, 1].contains(where: { abs(saved - HeartRateZoneCalculator(age: currentYear - year - $0).estimatedMaxHR) < 0.01 }) {
                HeartRateZoneCalculator.saveMaxHR(0)
                logger.info("Cleared frozen max HR estimate \(Int(saved)) BPM")
            }
            logger.info("Age from HealthKit date of birth: \(age)")
        } catch {
            logger.info("Date of birth not available in HealthKit: \(error.localizedDescription)")
        }
    }
}
