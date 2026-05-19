import SwiftUI

// MARK: - FM Tuner Footer Info Box
// Displays 1–3 lines of status text in a thin-bordered rectangle.
// Active screens drive the content via ThemeManager.shared.footerStatusLines.

struct FMTunerFooter: View {
    let lines: [String]

    private let brightCyan  = Color(red: 0.486, green: 0.847, blue: 1.000) // #7CD8FF textPrimary
    private let borderColor = Color(red: 0.039, green: 0.294, blue: 0.361) // #0A4B5C
    private let bgColor     = Color(red: 0.024, green: 0.125, blue: 0.161) // #062029

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(lines.prefix(3).enumerated()), id: \.offset) { _, line in
                Text(line)
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .foregroundStyle(brightCyan)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(bgColor)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(borderColor, lineWidth: 1)
        )
    }
}
