import SwiftUI

// MARK: - FM Tuner Station Tag
// Deterministically derives an FM frequency (88.0–107.9 MHz) from a UUID.
// Used in template cards when the FM Tuner theme is active.

struct FMTunerStationTag: View {
    let id: UUID

    var body: some View {
        Text(frequency)
            .font(.system(size: 11, weight: .heavy, design: .monospaced))
            .foregroundStyle(ShuttlXColor.textPrimary)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .stroke(ShuttlXColor.surfaceBorder, lineWidth: 1)
            )
    }

    /// Deterministic frequency in the 88.0–107.9 MHz band from UUID hash.
    private var frequency: String {
        let n = abs(id.uuidString.hashValue) % 200 + 880  // 880–1079
        return String(format: "%.1f MHz", Double(n) / 10.0)
    }
}
