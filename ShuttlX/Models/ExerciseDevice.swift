import Foundation

// MARK: - Device Category

enum DeviceCategory: String, Codable, CaseIterable, Identifiable {
    case treadmill
    case stationaryBike
    case rowingMachine
    case ellipticalMachine
    case stairClimber
    case skiErg
    case cableSystem
    case freeWeights
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .treadmill: return "Treadmill"
        case .stationaryBike: return "Stationary Bike"
        case .rowingMachine: return "Rowing Machine"
        case .ellipticalMachine: return "Elliptical Machine"
        case .stairClimber: return "Stair Climber"
        case .skiErg: return "Ski Erg"
        case .cableSystem: return "Cable System"
        case .freeWeights: return "Free Weights"
        case .custom: return "Custom"
        }
    }

    var defaultIcon: String {
        switch self {
        case .treadmill: return "figure.run"
        case .stationaryBike: return "figure.indoor.cycle"
        case .rowingMachine: return "figure.rower"
        case .ellipticalMachine: return "figure.elliptical"
        case .stairClimber: return "figure.stair.stepper"
        case .skiErg: return "figure.skiing.crosscountry"
        case .cableSystem: return "figure.strengthtraining.functional"
        case .freeWeights: return "dumbbell.fill"
        case .custom: return "figure.mixed.cardio"
        }
    }
}

// MARK: - Exercise Device

struct ExerciseDevice: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var category: DeviceCategory
    var sportType: WorkoutSport
    var isBuiltIn: Bool
    var defaultMET: Double
    var customMET: Double?
    var icon: String
    var createdDate: Date

    var effectiveMET: Double { customMET ?? defaultMET }

    init(
        id: UUID = UUID(),
        name: String,
        category: DeviceCategory,
        sportType: WorkoutSport,
        isBuiltIn: Bool = false,
        defaultMET: Double,
        customMET: Double? = nil,
        icon: String? = nil,
        createdDate: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.sportType = sportType
        self.isBuiltIn = isBuiltIn
        self.defaultMET = defaultMET
        self.customMET = customMET
        self.icon = icon ?? category.defaultIcon
        self.createdDate = createdDate
    }

    // MARK: - Built-in Devices

    static let builtInDevices: [ExerciseDevice] = [
        ExerciseDevice(
            name: "Treadmill",
            category: .treadmill,
            sportType: .running,
            isBuiltIn: true,
            defaultMET: 9.8
        ),
        ExerciseDevice(
            name: "Stationary Bike",
            category: .stationaryBike,
            sportType: .cycling,
            isBuiltIn: true,
            defaultMET: 7.5
        ),
        ExerciseDevice(
            name: "Rowing Machine",
            category: .rowingMachine,
            sportType: .crossTraining,
            isBuiltIn: true,
            defaultMET: 7.0
        ),
        ExerciseDevice(
            name: "Elliptical",
            category: .ellipticalMachine,
            sportType: .elliptical,
            isBuiltIn: true,
            defaultMET: 5.0
        ),
        ExerciseDevice(
            name: "Stair Climber",
            category: .stairClimber,
            sportType: .crossTraining,
            isBuiltIn: true,
            defaultMET: 9.0
        ),
        ExerciseDevice(
            name: "Ski Erg",
            category: .skiErg,
            sportType: .crossTraining,
            isBuiltIn: true,
            defaultMET: 6.8,
            icon: "figure.skiing.crosscountry"
        )
    ]
}
