import SwiftUI

// MARK: - FM Tuner Header Bar
// Displays antenna icon, "DATA SYNC" pill, and signal-strength dots.
// Rendered as an overlay at the top of every screen when theme is FM Tuner.

struct FMTunerHeader: View {

    private let brightCyan  = Color(red: 0.486, green: 0.847, blue: 1.000) // #7CD8FF
    private let midCyan     = Color(red: 0.227, green: 0.561, blue: 0.659) // #3A8FA8
    private let borderColor = Color(red: 0.039, green: 0.294, blue: 0.361) // #0A4B5C
    private let bgColor     = Color(red: 0.024, green: 0.125, blue: 0.161) // #062029

    var body: some View {
        HStack(spacing: 10) {
            // Antenna SF Symbol
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 16, weight: .heavy))
                .foregroundStyle(brightCyan)

            Spacer()

            // DATA SYNC pill (decorative for v1)
            Text("DATA SYNC \u{25C4}3\u{25BA}")
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .foregroundStyle(brightCyan)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(bgColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(borderColor, lineWidth: 1)
                )

            Spacer()

            // Signal strength dots (decorative — default 3 of 4 lit)
            HStack(spacing: 4) {
                ForEach(0..<4, id: \.self) { index in
                    Circle()
                        .fill(index < ThemeManager.shared.signalStrength ? brightCyan : midCyan.opacity(0.3))
                        .frame(width: 4, height: 4)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .frame(height: 36)
    }
}
