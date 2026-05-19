import SwiftUI

// MARK: - FM Tuner watchOS chrome decorations
//
// Watch-specific FM Tuner chrome. The 41mm screen has no room for the iOS
// header pill ("DATA SYNC ◀ 3 ▶") — instead the home screen renders a single
// compact line: antenna icon + 3 dim signal dots. Workout/recovery screens
// add a single-line footer with status text (vs iOS's 3-line footer).
//
// These views read state from `ThemeManager.shared` so screens stay
// theme-agnostic: only screens that opt-in display the chrome.

// MARK: - Compact header (home only)

/// Single compact line: antenna SF Symbol + 3 dim signal dots.
/// No "DATA SYNC" pill (too wide for watch). Total height ~16pt.
struct FMTunerCompactHeader: View {
    var body: some View {
        let theme = ThemeManager.shared
        HStack(spacing: 6) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(theme.colors.textPrimary)
            Spacer(minLength: 0)
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { _ in
                    Circle()
                        .fill(theme.colors.textSecondary)
                        .frame(width: 3, height: 3)
                }
            }
        }
        .frame(height: 16)
        .padding(.horizontal, 8)
        .padding(.top, 4)
    }
}

// MARK: - Single-line footer (workout + recovery)

/// Thin-bordered rounded rectangle with a single line of mono 10pt status text.
/// Reads `ThemeManager.shared.footerStatusLines.first` and renders it as a
/// single label. On watch the footer is ALWAYS one line (unlike iOS which
/// has 3 lines).
struct FMTunerSingleLineFooter: View {
    let text: String

    var body: some View {
        let theme = ThemeManager.shared
        Text(text)
            .font(.system(size: 10, weight: .heavy, design: .monospaced))
            .foregroundStyle(theme.colors.textPrimary)
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .stroke(theme.colors.surfaceBorder, lineWidth: 1)
            )
    }
}

// MARK: - VU column (Canvas)

/// Canvas-based VU bar with 14 stacked segments. Each segment is 3pt wide,
/// 4pt tall, separated by 1pt vertical gaps. The number of bright segments
/// scales with `level` (0.0–1.0). Above-threshold segments stroke in dim
/// cyan, below fill in bright cyan. Sharp corners — no rounding.
///
/// Geometry (watch): 14 * 4 + 13 * 1 = 69pt total height.
struct FMTunerWatchVUColumn: View {
    let level: Double

    // Segment metrics
    private let segmentCount = 14
    private let segmentWidth: CGFloat = 3
    private let segmentHeight: CGFloat = 4
    private let segmentGap: CGFloat = 1

    private var totalHeight: CGFloat {
        CGFloat(segmentCount) * segmentHeight + CGFloat(segmentCount - 1) * segmentGap
    }

    private var bright: Color {
        Color(red: 0.486, green: 0.847, blue: 1.000)  // #7CD8FF
    }
    private var dim: Color {
        Color(red: 0.055, green: 0.396, blue: 0.502)  // #0E6580
    }

    var body: some View {
        Canvas { ctx, size in
            let clamped = max(0.0, min(1.0, level))
            let filled = Int((clamped * Double(segmentCount)).rounded())
            // Draw bottom-up so the first lit segment is at the bottom of the column.
            for i in 0..<segmentCount {
                let yFromBottom = CGFloat(i) * (segmentHeight + segmentGap)
                let y = size.height - segmentHeight - yFromBottom
                let rect = CGRect(x: 0, y: y, width: segmentWidth, height: segmentHeight)
                if i < filled {
                    ctx.fill(Path(rect), with: .color(bright))
                } else {
                    ctx.stroke(Path(rect), with: .color(dim), lineWidth: 0.5)
                }
            }
        }
        .frame(width: segmentWidth, height: totalHeight)
    }
}
