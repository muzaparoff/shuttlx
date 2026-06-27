import SwiftUI

// MARK: - ThemeColors
//
// All properties carry Clean-theme defaults so new themes only declare what
// differs. Existing themes pass all values explicitly — no behaviour change.
// Use `var c = ThemeColors(); c.background = myBG` to build from a preset.

struct ThemeColors: Equatable {
    // Background & surfaces
    var background: Color     = Color(.systemBackground)
    var surface: Color        = Color(.secondarySystemBackground)
    var surfaceBorder: Color  = Color.clear

    // Activity
    var running: Color        = .green
    var walking: Color        = .orange
    var heartRate: Color      = .red
    var steps: Color          = .blue
    var calories: Color       = .orange
    var stationary: Color     = .secondary

    // Sport
    var cycling: Color        = .blue
    var swimming: Color       = .cyan
    var hiking: Color         = .brown
    var elliptical: Color     = .purple
    var crossTraining: Color  = .indigo

    // CTA
    var ctaPrimary: Color     = .green
    var ctaDestructive: Color = .red
    var ctaWarning: Color     = .orange
    var ctaPause: Color       = .yellow
    var iconOnCTA: Color      = .black

    // HR Zones (1-5)
    var hrZone1: Color        = .blue
    var hrZone2: Color        = .green
    var hrZone3: Color        = .yellow
    var hrZone4: Color        = .orange
    var hrZone5: Color        = .red

    // Interval steps
    var stepWork: Color       = .green
    var stepRest: Color       = .orange
    var stepWarmup: Color     = .blue
    var stepCooldown: Color   = .blue

    // Semantic
    var pace: Color           = .purple
    var positive: Color       = .green
    var negative: Color       = .orange

    // Recovery
    var recoveryFresh: Color         = .green
    var recoveryNormal: Color        = .blue
    var recoveryFatigued: Color      = .orange
    var recoveryOverreaching: Color  = .red

    // Pace zones
    var paceInterval: Color   = .red
    var paceThreshold: Color  = .orange
    var paceTempo: Color      = .yellow
    var paceModerate: Color   = .green
    var paceEasy: Color       = .blue

    // Text
    var textPrimary: Color    = Color(.label)
    var textSecondary: Color  = Color(.secondaryLabel)

    // Card backgrounds
    var cardBackground: Color = Color(.secondarySystemBackground)

    // Watch surfaces
    var watchCardBackground: Color   = Color.white.opacity(0.12)
    var watchButtonBackground: Color = Color.white.opacity(0.15)

    // MARK: - Helper Methods

    func forStepType(_ type: IntervalType) -> Color {
        switch type {
        case .work:     return stepWork
        case .rest:     return stepRest
        case .warmup:   return stepWarmup
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
        case "Interval":  return paceInterval
        case "Threshold": return paceThreshold
        case "Tempo":     return paceTempo
        case "Moderate":  return paceModerate
        case "Easy":      return paceEasy
        default:          return Color.gray
        }
    }
}
