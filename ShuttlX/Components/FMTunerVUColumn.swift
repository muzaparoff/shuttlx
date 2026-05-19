import SwiftUI

// MARK: - FM Tuner VU Column
// 18 stacked 4x6pt rectangles rendered via Canvas (no anti-aliasing).
// `value` is 0.0–1.0; segments below the fill line are bright cyan, above are dim.
// Pinned to the leading edge by the fmTunerBackground() modifier.

struct FMTunerVUColumn: View {

    var value: Double  // 0.0–1.0

    private let brightCyan = Color(red: 0.486, green: 0.847, blue: 1.000)  // #7CD8FF lit
    private let dimCyan    = Color(red: 0.055, green: 0.396, blue: 0.502)  // #0E6580 unlit

    private let totalBars: Int   = 18
    private let barW:    CGFloat = 4
    private let barH:    CGFloat = 6
    private let gap:     CGFloat = 2

    private var columnHeight: CGFloat {
        CGFloat(totalBars) * (barH + gap) - gap  // subtract trailing gap
    }

    var body: some View {
        Canvas { ctx, size in
            let lit = Int((value * Double(totalBars)).rounded()).clamped(to: 0...totalBars)
            for i in 0..<totalBars {
                // Stack bottom-to-top: index 0 = bottom segment
                let y = size.height - CGFloat(i + 1) * (barH + gap) + gap
                let rect = CGRect(x: 0, y: y, width: barW, height: barH)
                let fill = i < lit ? brightCyan : dimCyan
                ctx.fill(Path(rect), with: .color(fill))
            }
        }
        .frame(width: barW, height: columnHeight)
    }
}

// MARK: - Clamped helper

private extension Int {
    func clamped(to range: ClosedRange<Int>) -> Int {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
