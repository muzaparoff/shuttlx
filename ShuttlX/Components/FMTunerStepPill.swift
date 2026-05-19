import SwiftUI

// MARK: - FM Tuner Step Pill
// Double-bordered rectangle (outer + inner 1pt lines, 2pt gap).
// Rendered only when FM Tuner theme is active; wraps existing step label text.
//
// Usage:
//   if themeManager.current.id == "fmtuner" {
//       FMTunerStepPill(label: "WORK")
//   }

struct FMTunerStepPill: View {
    let label: String
    var color: Color = Color(red: 0.486, green: 0.847, blue: 1.000)  // default bright cyan

    var body: some View {
        Text(label)
            .font(.system(size: 16, weight: .heavy, design: .monospaced))
            .tracking(4)
            .foregroundStyle(color)
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            // Inner border layer
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .stroke(color, lineWidth: 1)
                    .padding(3)  // 2pt gap + 1pt outer = 3pt inset
            )
            // Outer border layer
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(color, lineWidth: 1)
            )
    }
}
