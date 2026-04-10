import Foundation
import os.log

@MainActor
class DeviceManager: ObservableObject {
    static let shared = DeviceManager()

    @Published var devices: [ExerciseDevice] = []

    private let logger = Logger(subsystem: "com.shuttlx.ShuttlX", category: "DeviceManager")
    private let fileName = "exercise_devices.json"
    private let appGroupIdentifier = "group.com.shuttlx.shared"

    // User body metrics stored in App Group UserDefaults
    private let weightKey = "userWeightKg"
    private let ageKey = "userAge"

    var userWeightKg: Double? {
        get {
            let val = userDefaults?.double(forKey: weightKey) ?? 0
            return val > 0 ? val : nil
        }
        set {
            if let weight = newValue, weight > 0 {
                userDefaults?.set(weight, forKey: weightKey)
            } else {
                userDefaults?.removeObject(forKey: weightKey)
            }
        }
    }

    var userAge: Int? {
        get {
            let val = userDefaults?.integer(forKey: ageKey) ?? 0
            return val > 0 ? val : nil
        }
        set {
            if let age = newValue, age > 0 {
                userDefaults?.set(age, forKey: ageKey)
            } else {
                userDefaults?.removeObject(forKey: ageKey)
            }
        }
    }

    private var userDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupIdentifier)
    }

    private init() {
        loadDevices()
    }

    // MARK: - CRUD

    func addDevice(_ device: ExerciseDevice) {
        devices.append(device)
        saveDevices()
    }

    func updateDevice(_ device: ExerciseDevice) {
        guard let index = devices.firstIndex(where: { $0.id == device.id }) else { return }
        devices[index] = device
        saveDevices()
    }

    func deleteDevice(_ device: ExerciseDevice) {
        guard !device.isBuiltIn else { return }
        devices.removeAll { $0.id == device.id }
        saveDevices()
    }

    func device(for id: UUID?) -> ExerciseDevice? {
        guard let id = id else { return nil }
        return devices.first { $0.id == id }
    }

    // MARK: - Persistence

    private func loadDevices() {
        guard let containerURL = getWorkingContainer() else {
            devices = ExerciseDevice.builtInDevices
            return
        }
        let url = containerURL.appendingPathComponent(fileName)
        guard FileManager.default.fileExists(atPath: url.path) else {
            devices = ExerciseDevice.builtInDevices
            saveDevices()
            return
        }

        do {
            let data = try Data(contentsOf: url)
            var loaded = try JSONDecoder().decode([ExerciseDevice].self, from: data)

            // Ensure built-in devices are always present
            for builtIn in ExerciseDevice.builtInDevices {
                if !loaded.contains(where: { $0.name == builtIn.name && $0.isBuiltIn }) {
                    loaded.append(builtIn)
                }
            }
            devices = loaded
            logger.info("Loaded \(self.devices.count) device(s)")
        } catch {
            logger.error("Failed to load devices: \(error.localizedDescription)")
            devices = ExerciseDevice.builtInDevices
            saveDevices()
        }
    }

    private func saveDevices() {
        guard let containerURL = getWorkingContainer() else { return }
        let url = containerURL.appendingPathComponent(fileName)
        do {
            let data = try JSONEncoder().encode(devices)
            try data.write(to: url, options: [.atomic, .completeFileProtection])
        } catch {
            logger.error("Failed to save devices: \(error.localizedDescription)")
        }
    }

    private func getWorkingContainer() -> URL? {
        if let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) {
            return container
        }
        guard let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        let fallback = docsURL.appendingPathComponent("SharedData")
        try? FileManager.default.createDirectory(at: fallback, withIntermediateDirectories: true)
        return fallback
    }
}
