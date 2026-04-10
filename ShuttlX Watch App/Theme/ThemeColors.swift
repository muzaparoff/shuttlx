import SwiftUI

struct ThemeColors: Equatable {
    // Background & surfaces
    let background: Color
    let surface: Color
    let surfaceBorder: Color

    // Activity
    let running: Color
    let walking: Color
    let heartRate: Color
    let steps: Color
    let calories: Color
    let stationary: Color

    // Sport
    let cycling: Color
    let swimming: Color
    let hiking: Color
    let elliptical: Color
    let crossTraining: Color

    // CTA
    let ctaPrimary: Color
    let ctaDestructive: Color
    let ctaWarning: Color
    let ctaPause: Color
    let iconOnCTA: Color

    // HR Zones (1-5)
    let hrZone1: Color
    let hrZone2: Color
    let hrZone3: Color
    let hrZone4: Color
    let hrZone5: Color

    // Interval steps
    let stepWork: Color
    let stepRest: Color
    let stepWarmup: Color
    let stepCooldown: Color

    // Semantic
    let pace: Color
    let positive: Color
    let negative: Color

    // Recovery
    let recoveryFresh: Color
    let recoveryNormal: Color
    let recoveryFatigued: Color
    let recoveryOverreaching: Color

    // Pace zones
    let paceInterval: Color
    let paceThreshold: Color
    let paceTempo: Color
    let paceModerate: Color
    let paceEasy: Color

    // Text
    let textPrimary: Color
    let textSecondary: Color

    // Card backgrounds
    let cardBackground: Color

    // Watch surfaces
    let watchCardBackground: Color
    let watchButtonBackground: Color

    // MARK: - Helper Methods

    func forStepType(_ type: IntervalType) -> Color {
        switch type {
        case .work: return stepWork
        case .rest: return stepRest
        case .warmup: return stepWarmup
        case .cooldown: return stepCooldown
        }
    }

    func forHRZone(_ heartRate: Int) -> Color {
        guard heartRate > 0 else { return self.heartRate }
        let calculator = HeartRateZoneCalculator.fromSharedDefaults()
        switch calculator.zone(for: Double(heartRate)) {
        case 1: return hrZone1
        case 2: return hrZone2
        case 3: return hrZone3
        case 4: return hrZone4
        default: return hrZone5
        }
    }

    func forPaceZone(_ zone: String) -> Color {
        switch zone {
        case "Interval": return paceInterval
        case "Threshold": return paceThreshold
        case "Tempo": return paceTempo
        case "Moderate": return paceModerate
        case "Easy": return paceEasy
        default: return Color.gray
        }
    }
}
