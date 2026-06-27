import SwiftUI

// MARK: - ThemeFonts
//
// All properties carry Clean-theme defaults so new themes only declare what
// differs. Existing themes pass all values explicitly — no behaviour change.
// Use `var f = ThemeFonts(); f.watchTimerDisplay = myFont` to build from a preset.

struct ThemeFonts: Equatable {
    // Shared
    var timerDisplay: Font   = .system(.largeTitle, design: .monospaced).weight(.semibold)
    var metricLarge: Font    = .system(.title2, design: .rounded).weight(.bold)
    var metricMedium: Font   = .system(.body, design: .rounded).weight(.semibold)
    var metricSmall: Font    = .system(.callout, design: .rounded).weight(.medium)
    var cardTitle: Font      = .headline
    var cardSubtitle: Font   = .subheadline
    var cardCaption: Font    = .caption
    var sectionHeader: Font  = .headline

    // iOS-specific (smaller defaults for watch context)
    var heroIcon: Font       = .system(size: 32, weight: .medium)
    var onboardingIcon: Font = .system(size: 48)
    var prValue: Font        = .system(.title3, design: .rounded).weight(.bold)
    var microLabel: Font     = .system(size: 9)
    var debugMono: Font      = .system(.caption, design: .monospaced)

    // watchOS-specific
    var watchTimerDisplay: Font     = .system(size: 36, weight: .bold, design: .monospaced)
    var watchMetricDisplay: Font    = .system(size: 40, weight: .bold, design: .rounded)
    var watchMetricSecondary: Font  = .system(size: 22, weight: .semibold, design: .rounded)
    var watchStepLabel: Font        = .system(size: 13, weight: .bold)
    var watchControlIcon: Font      = .system(size: 26, weight: .semibold)
    var watchControlLabel: Font     = .system(size: 11)
    var watchStatusBadge: Font      = .system(size: 13, weight: .bold)
    var watchSummaryTimer: Font     = .system(.title, design: .monospaced).weight(.bold)
    var watchSummaryMetric: Font    = .system(.body, design: .rounded).weight(.semibold)
    var watchHeroIcon: Font         = .system(size: 32, weight: .medium)
    var watchHeroTitle: Font        = .system(.title3, design: .rounded).weight(.semibold)
    var watchTemplateTitle: Font    = .system(.body, design: .rounded).weight(.semibold)
}
