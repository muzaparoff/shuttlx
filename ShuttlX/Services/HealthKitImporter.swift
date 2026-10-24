import Foundation
import HealthKit
import CoreLocation
import os.log
import ShuttlXShared

/// Reads ShuttlX workouts back from Apple Health so a session that never arrived over
/// WatchConnectivity still shows up in History. Results go through
/// `DataManager.handleReceivedSessions` (id dedup, persistence, widgets) — no second store.
@MainActor
final class HealthKitImporter: ObservableObject {
    static let shared = HealthKitImporter()

    @Published private(set) var lastImportDate: Date?
    @Published private(set) var lastImportCount = 0
    @Published private(set) var status = "Idle"
    /// Workouts read so far in the current import; nil when idle or nothing to read.
    @Published private(set) var progress: (done: Int, total: Int)?

    private let logger = Logger(subsystem: "com.shuttlx.ShuttlX", category: "HealthKitImporter")
    private let store = HKHealthStore()
    private let defaults = UserDefaults.standard
    private let anchorKey = "healthImport.anchor"
    private let deferredKey = "healthImport.deferredUUIDs"
    private let lastDateKey = "healthImport.lastDate"
    private let lastCountKey = "healthImport.lastCount"
    private let sourcePrefix = "com.shuttlx.ShuttlX"
    private let firstRunDays = 90
    private let maxRoutePoints = 2000

    private var isRunning = false
    private var observer: HKObserverQuery?
    private weak var dataManager: DataManager?

    private init() {
        lastImportDate = defaults.object(forKey: lastDateKey) as? Date
        lastImportCount = defaults.integer(forKey: lastCountKey)
    }

    // MARK: - Lifecycle

    /// Starts the observer (foreground only; no background delivery) once the importer may run.
    /// It never shows a Health sheet: access is requested by onboarding or Settings -> Health only.
    func start(dataManager: DataManager) async {
        self.dataManager = dataManager
        guard observer == nil, await mayRun() else { return }
        let q = HKObserverQuery(sampleType: HKObjectType.workoutType(), predicate: nil) { [weak self] _, completion, error in
            if let error { Logger(subsystem: "com.shuttlx.ShuttlX", category: "HealthKitImporter").error("Observer error: \(error.localizedDescription)") }
            Task { @MainActor in
                await self?.importNow()
                completion()
            }
        }
        observer = q
        store.execute(q)
    }

    /// Everything the import reads. Onboarding and Settings request these together with sharing, in ONE sheet.
    nonisolated static var readTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = [HKObjectType.workoutType(), HKSeriesType.workoutRoute()]
        let ids: [HKQuantityTypeIdentifier] = [.heartRate, .activeEnergyBurned, .distanceWalkingRunning,
                                               .distanceCycling, .distanceSwimming, .stepCount]
        for id in ids { if let t = HKQuantityType.quantityType(forIdentifier: id) { types.insert(t) } }
        return types
    }

    /// Runs only after onboarding is finished AND Health has already been asked for every type read here
    /// (`.unnecessary`). Before that the importer would pop a second Health sheet over onboarding.
    private func mayRun() async -> Bool {
        #if DEBUG
        let env = ProcessInfo.processInfo.environment
        if env["SHUTTLX_DEMO_DATA"] == "1" || env["SHUTTLX_NO_HEALTH"] == "1" { return false }   // demo / skipHealth seams
        #endif
        guard defaults.object(forKey: "isFirstLaunch") as? Bool == false,   // @AppStorage("isFirstLaunch")
              HKHealthStore.isHealthDataAvailable() else { return false }
        do {
            return try await store.statusForAuthorizationRequest(toShare: [], read: Self.readTypes) == .unnecessary
        } catch {
            logger.error("Health request status failed: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Import

    #if DEBUG
    func debugSetProgress(done: Int, total: Int) { progress = (done, total) }
    #endif

    func importNow() async {
        guard !isRunning, let dataManager else { return }
        isRunning = true
        defer { isRunning = false; progress = nil }
        guard await mayRun() else { status = "Waiting for Health access"; return }

        let fetched = await fetchNewWorkouts()
        let known = dataManager.sessions.map { HealthImportRules.Known(id: $0.id, start: $0.startDate, duration: $0.duration) }
        var deferred: [String] = []
        var built: [TrainingSession] = []
        let mine = fetched.workouts.filter { $0.sourceRevision.source.bundleIdentifier.hasPrefix(sourcePrefix) }
        var seen = 0
        progress = mine.isEmpty ? nil : (0, mine.count)
        for w in mine {
            seen += 1
            defer { progress = (seen, mine.count) }
            let ext = (w.metadata?[HKMetadataKeyExternalUUID] as? String).flatMap(UUID.init(uuidString:))
            if HealthImportRules.isAlreadyPresent(externalUUID: ext, workoutUUID: w.uuid, start: w.startDate,
                                                  duration: w.duration, known: known) { continue }
            guard HealthImportRules.isPastGrace(end: w.endDate) else {
                deferred.append(w.uuid.uuidString); continue
            }
            built.append(await makeSession(from: w))
        }

        #if DEBUG
        if dataManager.isDemoDataMode { return }
        #endif
        if !built.isEmpty {
            dataManager.handleReceivedSessions(built)
            lastImportDate = Date()
            lastImportCount = built.count
            defaults.set(lastImportDate, forKey: lastDateKey)
            defaults.set(built.count, forKey: lastCountKey)
        }
        // Only advance the anchor when the query actually returned something, so a
        // not-yet-granted read permission (indistinguishable from "no data") can't
        // skip history. Recent workouts are tracked in `deferred` instead.
        if let anchor = fetched.anchor, !fetched.workouts.isEmpty || fetched.hadDeletions {
            saveAnchor(anchor)
        }
        defaults.set(deferred, forKey: deferredKey)
        status = "Imported \(built.count), deferred \(deferred.count)"
        logger.info("Health import: fetched \(fetched.workouts.count), imported \(built.count), deferred \(deferred.count)")
    }

    // MARK: - Queries

    private func fetchNewWorkouts() async -> (workouts: [HKWorkout], anchor: HKQueryAnchor?, hadDeletions: Bool) {
        let since = Calendar.current.date(byAdding: .day, value: -firstRunDays, to: Date()) ?? .distantPast
        let predicate = HKQuery.predicateForSamples(withStart: since, end: nil, options: [])
        let anchor = loadAnchor()
        let log = logger
        var result: (workouts: [HKWorkout], anchor: HKQueryAnchor?, hadDeletions: Bool) = await withCheckedContinuation { cont in
            let q = HKAnchoredObjectQuery(type: HKObjectType.workoutType(), predicate: predicate, anchor: anchor,
                                          limit: HKObjectQueryNoLimit) { _, added, deleted, newAnchor, error in
                if let error { log.error("Anchored workout query failed: \(error.localizedDescription)") }
                cont.resume(returning: ((added as? [HKWorkout]) ?? [], newAnchor, !(deleted ?? []).isEmpty))
            }
            store.execute(q)
        }
        // Workouts skipped last time because they were too fresh.
        let ids = Set((defaults.stringArray(forKey: deferredKey) ?? []).compactMap(UUID.init(uuidString:)))
        if !ids.isEmpty {
            let again: [HKWorkout] = await withCheckedContinuation { cont in
                let q = HKSampleQuery(sampleType: HKObjectType.workoutType(),
                                      predicate: HKQuery.predicateForObjects(with: ids),
                                      limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                    if let error { log.error("Deferred workout query failed: \(error.localizedDescription)") }
                    cont.resume(returning: (samples as? [HKWorkout]) ?? [])
                }
                store.execute(q)
            }
            let have = Set(result.workouts.map(\.uuid))
            result.workouts += again.filter { !have.contains($0.uuid) }
        }
        return result
    }

    private func makeSession(from w: HKWorkout) async -> TrainingSession {
        let ext = w.metadata?[HKMetadataKeyExternalUUID] as? String
        let sport = Self.sport(for: w.workoutActivityType)

        func sum(_ id: HKQuantityTypeIdentifier, _ unit: HKUnit) -> Double? {
            guard let t = HKQuantityType.quantityType(forIdentifier: id),
                  let v = w.statistics(for: t)?.sumQuantity()?.doubleValue(for: unit), v > 0 else { return nil }
            return v
        }
        let meters = [HKQuantityTypeIdentifier.distanceWalkingRunning, .distanceCycling, .distanceSwimming]
            .compactMap { sum($0, .meter()) }.first
        let (avgHR, maxHR) = await heartRate(from: w.startDate, to: w.endDate)

        var session = TrainingSession(
            id: HealthImportRules.sessionID(externalUUIDString: ext, workoutUUID: w.uuid),
            startDate: w.startDate,
            endDate: w.endDate,
            duration: w.duration,
            averageHeartRate: avgHR,
            maxHeartRate: maxHR,
            caloriesBurned: sum(.activeEnergyBurned, .kilocalorie()),
            distance: meters.map { $0 / 1000 },
            totalSteps: sum(.stepCount, .count()).map(Int.init),
            segments: Self.segments(for: w, sport: sport)
        )
        session.sportType = sport
        session.importedFromHealth = true
        let route = await loadRoute(for: w)
        session.inlineRoute = route.isEmpty ? nil : route
        return session
    }

    private func heartRate(from start: Date, to end: Date) async -> (Double?, Double?) {
        guard let type = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return (nil, nil) }
        let unit = HKUnit.count().unitDivided(by: .minute())
        let predicate = HKSamplePredicate.quantitySample(
            type: type, predicate: HKQuery.predicateForSamples(withStart: start, end: end, options: []))
        do {
            let stats = try await HKStatisticsQueryDescriptor(predicate: predicate, options: [.discreteAverage, .discreteMax]).result(for: store)
            return (stats?.averageQuantity()?.doubleValue(for: unit), stats?.maximumQuantity()?.doubleValue(for: unit))
        } catch {
            logger.error("Heart rate statistics failed: \(error.localizedDescription)")
            return (nil, nil)
        }
    }

    private func loadRoute(for w: HKWorkout) async -> [RoutePoint] {
        let log = logger
        let routes: [HKWorkoutRoute] = await withCheckedContinuation { cont in
            let q = HKSampleQuery(sampleType: HKSeriesType.workoutRoute(),
                                  predicate: HKQuery.predicateForObjects(from: w),
                                  limit: HKObjectQueryNoLimit,
                                  sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]) { _, samples, error in
                if let error { log.error("Route sample query failed: \(error.localizedDescription)") }
                cont.resume(returning: (samples as? [HKWorkoutRoute]) ?? [])
            }
            store.execute(q)
        }
        var points: [RoutePoint] = []
        for route in routes {
            do {
                for try await loc in HKWorkoutRouteQueryDescriptor(route).results(for: store) {
                    points.append(RoutePoint(latitude: loc.coordinate.latitude, longitude: loc.coordinate.longitude,
                                             altitude: loc.verticalAccuracy >= 0 ? loc.altitude : nil,
                                             timestamp: loc.timestamp,
                                             speed: loc.speed >= 0 ? loc.speed : nil,
                                             horizontalAccuracy: loc.horizontalAccuracy >= 0 ? loc.horizontalAccuracy : nil))
                }
            } catch {
                logger.error("Route read failed: \(error.localizedDescription)")
            }
        }
        return HealthImportRules.downsample(points, limit: maxRoutePoints)
    }

    // MARK: - Mapping

    private static func segments(for w: HKWorkout, sport: WorkoutSport) -> [ActivitySegment] {
        let activities = w.workoutActivities.sorted { $0.startDate < $1.startDate }
        guard !activities.isEmpty else {
            return [ActivitySegment(activityType: HealthImportRules.activity(phaseMetadata: nil, sport: sport),
                                    startDate: w.startDate, endDate: w.endDate)]
        }
        return activities.map { a in
            let md = a.metadata
            func num(_ key: String) -> Double? { (md?[key] as? NSNumber)?.doubleValue }
            return ActivitySegment(
                activityType: HealthImportRules.activity(phaseMetadata: md?["com.shuttlx.phase"] as? String, sport: sport),
                startDate: a.startDate, endDate: a.endDate ?? w.endDate,
                steps: num("com.shuttlx.steps").map(Int.init),
                distance: num("com.shuttlx.distanceKilometers"),
                averageHeartRate: num("com.shuttlx.averageHeartRate"),
                estimatedCalories: num("com.shuttlx.kilocaloriesShuttlX"),
                activeEnergyCalories: num("com.shuttlx.kilocaloriesApple"))
        }
    }

    private static func sport(for type: HKWorkoutActivityType) -> WorkoutSport {
        switch type {
        case .running: return .running
        case .walking: return .walking
        case .cycling: return .cycling
        case .swimming: return .swimming
        case .hiking: return .hiking
        case .elliptical: return .elliptical
        case .crossTraining: return .crossTraining
        default: return .other
        }
    }

    // MARK: - Anchor persistence

    private func loadAnchor() -> HKQueryAnchor? {
        guard let data = defaults.data(forKey: anchorKey) else { return nil }
        do {
            return try NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: data)
        } catch {
            logger.error("Anchor decode failed, restarting from window: \(error.localizedDescription)")
            return nil
        }
    }

    private func saveAnchor(_ anchor: HKQueryAnchor) {
        do {
            defaults.set(try NSKeyedArchiver.archivedData(withRootObject: anchor, requiringSecureCoding: true), forKey: anchorKey)
        } catch {
            logger.error("Anchor encode failed: \(error.localizedDescription)")
        }
    }
}
