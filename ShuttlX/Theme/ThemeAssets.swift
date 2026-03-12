import SwiftUI
import Foundation

// MARK: - Themed Timer Frame

struct ThemedTimerFrame: View {
    var width: CGFloat = 160
    var height: CGFloat = 160

    var body: some View {
        let themeID = ThemeManager.shared.current.id
        switch themeID {
        case "synthwave":    SynthwaveTimerFrame(width: width, height: height)
        case "mixtape":      MixtapeTimerFrame(width: width, height: height)
        case "arcade":       ArcadeTimerFrame(width: width, height: height)
        case "classicradio": ClassicRadioTimerFrame(width: width, height: height)
        case "vumeter":      VUMeterTimerFrame(width: width, height: height)
        default:             CleanTimerFrame(width: width, height: height)
        }
    }
}

// MARK: Clean Timer Frame — premium glass chronograph with beveled edges + chapter ring

private struct CleanTimerFrame: View {
    let width: CGFloat
    let height: CGFloat
    private var size: CGFloat { min(width, height) }

    var body: some View {
        ZStack {
            // Ambient glow behind frame
            RoundedRectangle(cornerRadius: 30)
                .fill(
                    RadialGradient(
                        colors: [Color.indigo.opacity(0.06), .clear],
                        center: .center, startRadius: 0, endRadius: size / 2
                    )
                )
                .frame(width: width + 16, height: height + 16)
                .allowsHitTesting(false)

            // Outer beveled stroke
            RoundedRectangle(cornerRadius: 28)
                .stroke(
                    LinearGradient(
                        colors: [Color.indigo.opacity(0.3), Color.blue.opacity(0.15)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: 4
                )
                .frame(width: width, height: height)

            // Inner beveled stroke (gap creates bevel feel)
            RoundedRectangle(cornerRadius: 22)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.18), Color.white.opacity(0.06)],
                        startPoint: .top, endPoint: .bottom
                    ),
                    lineWidth: 1.5
                )
                .frame(width: width - 8, height: height - 8)

            // 12-mark chapter ring (4 cardinal + 8 intermediate)
            ForEach(0..<12, id: \.self) { i in
                let angle = Double(i) * 30.0
                let isCardinal = i % 3 == 0
                TickMark(
                    color: .white.opacity(isCardinal ? 0.2 : 0.1),
                    length: isCardinal ? 6 : 3,
                    width: isCardinal ? 1.5 : 1
                )
                .rotationEffect(.degrees(angle))
            }
            .frame(width: size - 6, height: size - 6)

            // Top specular arc
            Canvas { context, canvasSize in
                let arcW = canvasSize.width * 0.55
                let arcX = (canvasSize.width - arcW) / 2
                let arcY: CGFloat = 10
                var path = Path()
                path.move(to: CGPoint(x: arcX, y: arcY + 2))
                path.addQuadCurve(
                    to: CGPoint(x: arcX + arcW, y: arcY + 2),
                    control: CGPoint(x: canvasSize.width / 2, y: arcY - 2)
                )
                context.stroke(path, with: .color(.white.opacity(0.12)), lineWidth: 2)
            }
            .frame(width: width, height: height)
            .allowsHitTesting(false)

            // Bottom shadow line
            RoundedRectangle(cornerRadius: 1)
                .fill(Color.black.opacity(0.05))
                .frame(width: width * 0.5, height: 1)
                .offset(y: height / 2 - 14)

            // Center cross-hair
            Canvas { context, canvasSize in
                let cx = canvasSize.width / 2
                let cy = canvasSize.height / 2
                let arm: CGFloat = 2
                let color = Color.white.opacity(0.06)
                // Horizontal
                var h = Path()
                h.move(to: CGPoint(x: cx - arm, y: cy))
                h.addLine(to: CGPoint(x: cx + arm, y: cy))
                context.stroke(h, with: .color(color), lineWidth: 1)
                // Vertical
                var v = Path()
                v.move(to: CGPoint(x: cx, y: cy - arm))
                v.addLine(to: CGPoint(x: cx, y: cy + arm))
                context.stroke(v, with: .color(color), lineWidth: 1)
            }
            .frame(width: width, height: height)
            .allowsHitTesting(false)
        }
        .frame(width: width, height: height)
    }
}

// MARK: Synthwave Timer Frame — neon holographic display with circuit nodes

private struct SynthwaveTimerFrame: View {
    let width: CGFloat
    let height: CGFloat
    private var size: CGFloat { min(width, height) }
    private let cyan = Color(red: 0.0, green: 0.96, blue: 1.0)
    private let magenta = Color(red: 1.0, green: 0.18, blue: 0.58)

    var body: some View {
        ZStack {
            // Dark background fill
            RoundedRectangle(cornerRadius: 26)
                .fill(Color(red: 0.04, green: 0.04, blue: 0.1))
                .frame(width: width, height: height)

            // Outer magenta glow border
            RoundedRectangle(cornerRadius: 24)
                .stroke(magenta.opacity(0.4), lineWidth: 2)
                .frame(width: width - 4, height: height - 4)
                .shadow(color: magenta.opacity(0.3), radius: 8)

            // Main cyan neon frame
            RoundedRectangle(cornerRadius: 22)
                .stroke(cyan, lineWidth: 3)
                .frame(width: width - 12, height: height - 12)
                .shadow(color: cyan.opacity(0.5), radius: 6)
                .shadow(color: cyan.opacity(0.25), radius: 12)

            // Chrome top edge on inner frame
            Canvas { context, canvasSize in
                let inset: CGFloat = 12
                let cr: CGFloat = 22
                var path = Path()
                path.move(to: CGPoint(x: inset + cr, y: inset))
                path.addLine(to: CGPoint(x: canvasSize.width - inset - cr, y: inset))
                context.stroke(path, with: .color(.white.opacity(0.12)), lineWidth: 1)
            }
            .frame(width: width, height: height)
            .allowsHitTesting(false)

            // Inner thin cyan frame
            RoundedRectangle(cornerRadius: 18)
                .stroke(cyan.opacity(0.3), lineWidth: 1)
                .frame(width: width - 24, height: height - 24)

            // Corner circuit nodes
            Canvas { context, canvasSize in
                let nodeSize: CGFloat = 6
                let lineLen: CGFloat = 8
                let inset: CGFloat = 14
                let nodeColor = cyan.opacity(0.4)

                let corners: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
                    (inset, inset, 1, 1),                                                   // top-left
                    (canvasSize.width - inset - nodeSize, inset, -1, 1),                     // top-right
                    (inset, canvasSize.height - inset - nodeSize, 1, -1),                    // bottom-left
                    (canvasSize.width - inset - nodeSize, canvasSize.height - inset - nodeSize, -1, -1) // bottom-right
                ]

                for (x, y, dx, dy) in corners {
                    // Filled square node
                    context.fill(
                        Path(CGRect(x: x, y: y, width: nodeSize, height: nodeSize)),
                        with: .color(nodeColor)
                    )
                    // Horizontal line extension
                    var hLine = Path()
                    hLine.move(to: CGPoint(x: x + (dx > 0 ? nodeSize : 0), y: y + nodeSize / 2))
                    hLine.addLine(to: CGPoint(x: x + (dx > 0 ? nodeSize : 0) + lineLen * dx, y: y + nodeSize / 2))
                    context.stroke(hLine, with: .color(nodeColor), lineWidth: 1)
                    // Vertical line extension
                    var vLine = Path()
                    vLine.move(to: CGPoint(x: x + nodeSize / 2, y: y + (dy > 0 ? nodeSize : 0)))
                    vLine.addLine(to: CGPoint(x: x + nodeSize / 2, y: y + (dy > 0 ? nodeSize : 0) + lineLen * dy))
                    context.stroke(vLine, with: .color(nodeColor), lineWidth: 1)
                }
            }
            .frame(width: width, height: height)
            .allowsHitTesting(false)

            // Horizontal scan line pair at 25% and 75%
            Canvas { context, canvasSize in
                let lineColor = cyan.opacity(0.08)
                let inset: CGFloat = 14
                for frac in [0.25, 0.75] {
                    let y = canvasSize.height * frac
                    var path = Path()
                    path.move(to: CGPoint(x: inset, y: y))
                    path.addLine(to: CGPoint(x: canvasSize.width - inset, y: y))
                    context.stroke(path, with: .color(lineColor), lineWidth: 0.5)
                }
            }
            .frame(width: width, height: height)
            .allowsHitTesting(false)

            // Inner corner chamfers (magenta 45-degree lines)
            Canvas { context, canvasSize in
                let inset: CGFloat = 13
                let cham: CGFloat = 3
                let color = magenta.opacity(0.15)
                let corners: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
                    (inset, inset, 1, 1),
                    (canvasSize.width - inset, inset, -1, 1),
                    (inset, canvasSize.height - inset, 1, -1),
                    (canvasSize.width - inset, canvasSize.height - inset, -1, -1)
                ]
                for (x, y, dx, dy) in corners {
                    var path = Path()
                    path.move(to: CGPoint(x: x, y: y + cham * dy))
                    path.addLine(to: CGPoint(x: x + cham * dx, y: y))
                    context.stroke(path, with: .color(color), lineWidth: 1)
                }
            }
            .frame(width: width, height: height)
            .allowsHitTesting(false)

            // Holographic dot grid inside inner frame
            DotGrid(color: cyan.opacity(0.03), dotSize: 0.6, spacing: 8)
                .frame(width: width - 28, height: height - 28)
                .allowsHitTesting(false)

            // Bottom magenta glow bleed
            RadialGradient(
                colors: [magenta.opacity(0.08), .clear],
                center: .init(x: 0.5, y: 1.0), startRadius: 0, endRadius: size * 0.4
            )
            .frame(width: width - 12, height: height - 12)
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .allowsHitTesting(false)

            // Cyan tick marks at cardinal positions
            ForEach([0, 90, 180, 270], id: \.self) { angle in
                TickMark(color: cyan.opacity(0.8), length: 8, width: 2)
                    .rotationEffect(.degrees(Double(angle)))
            }
            .frame(width: size - 6, height: size - 6)

            // Magenta accent ticks at diagonals
            ForEach([45, 135, 225, 315], id: \.self) { angle in
                TickMark(color: magenta.opacity(0.4), length: 5, width: 1.5)
                    .rotationEffect(.degrees(Double(angle)))
            }
            .frame(width: size - 6, height: size - 6)
        }
        .frame(width: width, height: height)
    }
}

// MARK: Mixtape Timer Frame — portable player LCD screen with bezel + screws

private struct MixtapeTimerFrame: View {
    let width: CGFloat
    let height: CGFloat
    private let lcdGreen = Color(red: 0.22, green: 1.0, blue: 0.08)
    private let playerBlue = Color(red: 0.29, green: 0.42, blue: 0.60)

    var body: some View {
        ZStack {
            // Green-gray LCD fill
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(red: 0.08, green: 0.14, blue: 0.10))

            // Outer bezel (3D plastic effect)
            RoundedRectangle(cornerRadius: 6)
                .stroke(
                    LinearGradient(
                        colors: [playerBlue.opacity(0.8), playerBlue.opacity(0.4)],
                        startPoint: .top, endPoint: .bottom
                    ),
                    lineWidth: 3
                )

            // Inner inset border
            RoundedRectangle(cornerRadius: 4)
                .stroke(lcdGreen.opacity(0.12), lineWidth: 1)
                .padding(5)

            // Green accent line at LCD top edge
            Canvas { context, canvasSize in
                var path = Path()
                path.move(to: CGPoint(x: 8, y: 6))
                path.addLine(to: CGPoint(x: canvasSize.width - 8, y: 6))
                context.stroke(path, with: .color(lcdGreen.opacity(0.2)), lineWidth: 0.5)
            }
            .frame(width: width, height: height)
            .allowsHitTesting(false)

            // Corner screws
            GeometryReader { geo in
                let inset: CGFloat = 8
                ForEach(0..<4, id: \.self) { corner in
                    ScrewDecoration(color: playerBlue.opacity(0.35))
                        .frame(width: 4, height: 4)
                        .position(screwPosition(corner: corner, w: geo.size.width, h: geo.size.height, inset: inset))
                }
            }

            // Dot matrix texture
            DotGrid(color: lcdGreen.opacity(0.04), dotSize: 0.8, spacing: 6)
                .frame(width: width - 12, height: height - 12)
                .allowsHitTesting(false)

            // LCD segment dividers (dashed lines at 1/3 and 2/3)
            Canvas { context, canvasSize in
                let lineColor = lcdGreen.opacity(0.08)
                let inset: CGFloat = 8
                for frac in [1.0 / 3.0, 2.0 / 3.0] {
                    let y = canvasSize.height * frac
                    var path = Path()
                    path.move(to: CGPoint(x: inset, y: y))
                    path.addLine(to: CGPoint(x: canvasSize.width - inset, y: y))
                    context.stroke(path, with: .color(lineColor), style: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                }
            }
            .frame(width: width, height: height)
            .allowsHitTesting(false)

            // Glass reflection (top 30%)
            LinearGradient(
                colors: [Color.white.opacity(0.03), .clear],
                startPoint: .top, endPoint: .init(x: 0.5, y: 0.3)
            )
            .frame(width: width - 6, height: height - 6)
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .allowsHitTesting(false)

            // Tape counter display
            Text("000")
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .foregroundColor(lcdGreen.opacity(0.3))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(8)

            // Transport row: rewind + play + fast-forward
            HStack(spacing: 6) {
                Image(systemName: "backward.fill")
                    .font(.system(size: 5))
                    .foregroundColor(playerBlue.opacity(0.2))
                Image(systemName: "play.fill")
                    .font(.system(size: 6))
                    .foregroundColor(playerBlue.opacity(0.35))
                Image(systemName: "forward.fill")
                    .font(.system(size: 5))
                    .foregroundColor(playerBlue.opacity(0.2))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, 7)
        }
        .frame(width: width, height: height)
    }

    private func screwPosition(corner: Int, w: CGFloat, h: CGFloat, inset: CGFloat) -> CGPoint {
        switch corner {
        case 0: return CGPoint(x: inset, y: inset)
        case 1: return CGPoint(x: w - inset, y: inset)
        case 2: return CGPoint(x: inset, y: h - inset)
        case 3: return CGPoint(x: w - inset, y: h - inset)
        default: return .zero
        }
    }
}

// MARK: Classic Radio Timer Frame — vintage cassette label with tape window + reels

private struct ClassicRadioTimerFrame: View {
    let width: CGFloat
    let height: CGFloat
    private let cream = Color(red: 0.96, green: 0.90, blue: 0.78)
    private let brown = Color(red: 0.35, green: 0.29, blue: 0.20)
    private let amber = Color(red: 0.91, green: 0.63, blue: 0.19)

    var body: some View {
        ZStack {
            // Cream label fill
            RoundedRectangle(cornerRadius: 6)
                .fill(cream.opacity(0.08))

            // Brown border (slightly rounder)
            RoundedRectangle(cornerRadius: 6)
                .stroke(brown, lineWidth: 2)

            // Aged paper grain (irregular dot pattern)
            Canvas { context, canvasSize in
                let grainColor = brown.opacity(0.03)
                // Pseudo-random dot pattern using deterministic positions
                var seed: UInt64 = 42
                for _ in 0..<80 {
                    seed = seed &* 6364136223846793005 &+ 1442695040888963407
                    let x = CGFloat(seed % UInt64(canvasSize.width * 10)) / 10.0
                    seed = seed &* 6364136223846793005 &+ 1442695040888963407
                    let y = CGFloat(seed % UInt64(canvasSize.height * 10)) / 10.0
                    context.fill(
                        Path(ellipseIn: CGRect(x: x, y: y, width: 0.8, height: 0.8)),
                        with: .color(grainColor)
                    )
                }
            }
            .frame(width: width - 4, height: height - 4)
            .allowsHitTesting(false)

            // Lined paper texture (horizontal rules)
            Canvas { context, canvasSize in
                let lineColor = brown.opacity(0.12)
                for y in stride(from: CGFloat(16), to: canvasSize.height - 20, by: 10) {
                    var path = Path()
                    path.move(to: CGPoint(x: 6, y: y))
                    path.addLine(to: CGPoint(x: canvasSize.width - 6, y: y))
                    context.stroke(path, with: .color(lineColor), lineWidth: 0.5)
                }
            }
            .padding(2)
            .allowsHitTesting(false)

            // Inner inset
            RoundedRectangle(cornerRadius: 3)
                .stroke(cream.opacity(0.1), lineWidth: 1)
                .padding(5)

            // "SIDE A" label at top with divider line
            VStack(spacing: 1) {
                Text("SIDE A")
                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                    .foregroundColor(brown.opacity(0.5))
                Rectangle()
                    .fill(brown.opacity(0.2))
                    .frame(width: 28, height: 0.5)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.top, 5)

            // "C-60" label at top-right
            Text("C-60")
                .font(.system(size: 6, weight: .medium, design: .monospaced))
                .foregroundColor(brown.opacity(0.3))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.top, 6)
                .padding(.trailing, 8)

            // Tape window (darker rounded rect in lower-center)
            VStack {
                Spacer()
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(red: 0.12, green: 0.09, blue: 0.06).opacity(0.6))
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(cream.opacity(0.12), lineWidth: 1)

                    // Red leader stripe at top of tape window
                    Canvas { context, canvasSize in
                        var path = Path()
                        path.move(to: CGPoint(x: 4, y: 2))
                        path.addLine(to: CGPoint(x: canvasSize.width - 4, y: 2))
                        context.stroke(path, with: .color(Color.red.opacity(0.15)), lineWidth: 0.5)
                    }
                    .allowsHitTesting(false)

                    // Reel hubs inside tape window
                    HStack {
                        ReelHub(color: brown.opacity(0.25), hubColor: brown.opacity(0.15))
                            .frame(width: 14, height: 14)
                        Spacer()
                        ReelHub(color: brown.opacity(0.25), hubColor: brown.opacity(0.15))
                            .frame(width: 14, height: 14)
                    }
                    .padding(.horizontal, 6)
                }
                .frame(width: width * 0.6, height: height * 0.2)
                .padding(.bottom, 7)
            }
        }
        .frame(width: width, height: height)
    }
}

// MARK: VU Meter Timer Frame — professional audio meter panel with mounting screws

private struct VUMeterTimerFrame: View {
    let width: CGFloat
    let height: CGFloat
    private let amber = Color(red: 0.91, green: 0.63, blue: 0.19)
    private let darkPanel = Color(red: 0.07, green: 0.05, blue: 0.03)

    var body: some View {
        ZStack {
            // Dark meter panel fill
            RoundedRectangle(cornerRadius: 8)
                .fill(darkPanel)

            // Brushed metal texture (horizontal lines)
            Canvas { context, canvasSize in
                let lineColor = amber.opacity(0.01)
                for y in stride(from: CGFloat(0), to: canvasSize.height, by: 0.5) {
                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: canvasSize.width, y: y))
                    context.stroke(path, with: .color(lineColor), lineWidth: 0.3)
                }
            }
            .frame(width: width - 4, height: height - 4)
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .allowsHitTesting(false)

            // Amber border
            RoundedRectangle(cornerRadius: 8)
                .stroke(amber.opacity(0.4), lineWidth: 2)

            // Beveled inset (double-line: dark + bright)
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.black.opacity(0.15), lineWidth: 1.5)
                .padding(5)
            RoundedRectangle(cornerRadius: 5)
                .stroke(amber.opacity(0.08), lineWidth: 0.5)
                .padding(7)

            // VU arc markings with scale labels, dual arc, needle + counterweight
            Canvas { context, canvasSize in
                let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height * 0.7)
                let radius = min(canvasSize.width, canvasSize.height) * 0.32

                // Main arc path
                var arcPath = Path()
                arcPath.addArc(center: center, radius: radius,
                              startAngle: .degrees(-150), endAngle: .degrees(-30),
                              clockwise: false)
                context.stroke(arcPath, with: .color(amber.opacity(0.2)), lineWidth: 1)

                // Secondary inner arc (at 70% radius)
                let innerRadius = radius * 0.7
                var innerArc = Path()
                innerArc.addArc(center: center, radius: innerRadius,
                               startAngle: .degrees(-145), endAngle: .degrees(-35),
                               clockwise: false)
                context.stroke(innerArc, with: .color(amber.opacity(0.08)), lineWidth: 0.5)

                // Inner arc tick marks (5 simple ticks)
                let innerTickAngles: [Double] = [-140, -115, -90, -65, -40]
                for angle in innerTickAngles {
                    let rad = angle * .pi / 180
                    let tInner = innerRadius - 3
                    let tOuter = innerRadius + 3
                    var tick = Path()
                    tick.move(to: CGPoint(
                        x: center.x + cos(rad) * tInner,
                        y: center.y + sin(rad) * tInner
                    ))
                    tick.addLine(to: CGPoint(
                        x: center.x + cos(rad) * tOuter,
                        y: center.y + sin(rad) * tOuter
                    ))
                    context.stroke(tick, with: .color(amber.opacity(0.12)), lineWidth: 0.5)
                }

                // Scale labels
                let labels = ["-20", "-10", "-7", "-5", "-3", "0", "+1", "+2", "+3"]
                let labelAngles: [Double] = [-150, -135, -120, -105, -90, -75, -60, -45, -30]

                for (i, label) in labels.enumerated() {
                    let angle = labelAngles[i]
                    let rad = angle * .pi / 180
                    let innerR = radius - 5
                    let outerR = radius + 5
                    let labelR = radius + 14
                    let isRed = i >= 6
                    let tickColor = isRed ? Color.red.opacity(0.4) : amber.opacity(0.3)

                    // Tick marks
                    var tick = Path()
                    tick.move(to: CGPoint(
                        x: center.x + cos(rad) * innerR,
                        y: center.y + sin(rad) * innerR
                    ))
                    tick.addLine(to: CGPoint(
                        x: center.x + cos(rad) * outerR,
                        y: center.y + sin(rad) * outerR
                    ))
                    context.stroke(tick, with: .color(tickColor), lineWidth: 1)

                    // Scale label text
                    let lx: CGFloat = center.x + cos(rad) * labelR - 6
                    let ly: CGFloat = center.y + sin(rad) * labelR - 4
                    let labelPoint = CGPoint(x: lx, y: ly)
                    context.draw(
                        Text(label)
                            .font(.system(size: 5, weight: .medium, design: .monospaced))
                            .foregroundColor(isRed ? .red.opacity(0.3) : amber.opacity(0.25)),
                        at: labelPoint, anchor: .center
                    )
                }

                // Needle at ~75% position
                let needleAngle = -60.0 * .pi / 180
                var needle = Path()
                needle.move(to: center)
                needle.addLine(to: CGPoint(
                    x: center.x + cos(needleAngle) * (radius - 2),
                    y: center.y + sin(needleAngle) * (radius - 2)
                ))
                context.stroke(needle, with: .color(amber.opacity(0.5)), lineWidth: 1)

                // Needle counterweight (opposite end)
                let counterAngle = needleAngle + .pi
                let counterR: CGFloat = 3
                let cx = center.x + cos(counterAngle) * 6
                let cy = center.y + sin(counterAngle) * 6
                context.fill(
                    Path(ellipseIn: CGRect(x: cx - counterR, y: cy - counterR, width: counterR * 2, height: counterR * 2)),
                    with: .color(amber.opacity(0.3))
                )

                // Needle pivot dot
                context.fill(
                    Path(ellipseIn: CGRect(x: center.x - 2, y: center.y - 2, width: 4, height: 4)),
                    with: .color(amber.opacity(0.4))
                )
            }
            .padding(2)
            .allowsHitTesting(false)

            // "VU" and "dB" text below arc
            HStack(spacing: 2) {
                Text("VU")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundColor(amber.opacity(0.3))
                Text("dB")
                    .font(.system(size: 5, weight: .medium, design: .monospaced))
                    .foregroundColor(amber.opacity(0.2))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, 6)

            // LED bar graph (5 rectangles: 3 green, 2 red)
            HStack(spacing: 2) {
                ForEach(0..<5, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 0.5)
                        .fill(i < 3 ? Color.green.opacity(0.3) : Color.red.opacity(0.3))
                        .frame(width: 4, height: 3)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            .padding(.bottom, 7)
            .padding(.trailing, 10)

            // Mounting screws at corners
            GeometryReader { geo in
                let inset: CGFloat = 6
                ForEach(0..<4, id: \.self) { corner in
                    ScrewDecoration(color: amber.opacity(0.2))
                        .frame(width: 3, height: 3)
                        .position(mountScrewPosition(corner: corner, w: geo.size.width, h: geo.size.height, inset: inset))
                }
            }
        }
        .frame(width: width, height: height)
    }

    private func mountScrewPosition(corner: Int, w: CGFloat, h: CGFloat, inset: CGFloat) -> CGPoint {
        switch corner {
        case 0: return CGPoint(x: inset, y: inset)
        case 1: return CGPoint(x: w - inset, y: inset)
        case 2: return CGPoint(x: inset, y: h - inset)
        case 3: return CGPoint(x: w - inset, y: h - inset)
        default: return .zero
        }
    }
}

// MARK: Arcade Timer Frame — CRT monitor cabinet with bezel + sub-pixel dots

private struct ArcadeTimerFrame: View {
    let width: CGFloat
    let height: CGFloat
    private var size: CGFloat { min(width, height) }
    private let phosphorGreen = Color(red: 0.0, green: 1.0, blue: 0.0)
    private let accentOrange = Color(red: 1.0, green: 0.67, blue: 0.0)

    var body: some View {
        ZStack {
            // CRT bezel gradient fill
            RoundedRectangle(cornerRadius: 4)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.12, green: 0.10, blue: 0.22),
                            Color(red: 0.06, green: 0.05, blue: 0.12)
                        ],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .frame(width: width, height: height)

            // Outer pixel border
            RoundedRectangle(cornerRadius: 4)
                .stroke(phosphorGreen.opacity(0.5), lineWidth: 3)
                .frame(width: width, height: height)

            // Inner dashed pixel ring
            RoundedRectangle(cornerRadius: 4)
                .stroke(phosphorGreen.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [4, 4]))
                .frame(width: width - 10, height: height - 10)

            // "SCORE" text at top
            Text("SCORE")
                .font(.system(size: 7, weight: .heavy, design: .monospaced))
                .foregroundColor(accentOrange.opacity(0.4))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.top, 6)

            // "CREDIT 0" text at bottom
            Text("CREDIT 0")
                .font(.system(size: 6, weight: .medium, design: .monospaced))
                .foregroundColor(phosphorGreen.opacity(0.25))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 6)

            // Larger pixel corners (12x12pt L-shaped brackets)
            ForEach(0..<4, id: \.self) { corner in
                PixelCorner(color: phosphorGreen.opacity(0.6))
                    .frame(width: 12, height: 12)
                    .offset(pixelCornerOffset(corner: corner))
            }

            // Display zone dividers (dashed lines at 1/3 and 2/3)
            Canvas { context, canvasSize in
                let lineColor = phosphorGreen.opacity(0.08)
                let inset: CGFloat = 8
                for frac in [1.0 / 3.0, 2.0 / 3.0] {
                    let y = canvasSize.height * frac
                    var path = Path()
                    path.move(to: CGPoint(x: inset, y: y))
                    path.addLine(to: CGPoint(x: canvasSize.width - inset, y: y))
                    context.stroke(path, with: .color(lineColor), style: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
                }
            }
            .frame(width: width, height: height)
            .allowsHitTesting(false)

            // Sub-pixel dot pattern
            DotGrid(color: phosphorGreen.opacity(0.02), dotSize: 0.6, spacing: 4)
                .frame(width: width - 12, height: height - 12)
                .allowsHitTesting(false)

            // Green tick marks
            ForEach([0, 90, 180, 270], id: \.self) { angle in
                TickMark(color: phosphorGreen.opacity(0.6), length: 6, width: 2)
                    .rotationEffect(.degrees(Double(angle)))
            }
            .frame(width: size - 4, height: size - 4)

            // Orange accent pixels at diagonals
            ForEach([45, 135, 225, 315], id: \.self) { angle in
                TickMark(color: accentOrange.opacity(0.4), length: 4, width: 2)
                    .rotationEffect(.degrees(Double(angle)))
            }
            .frame(width: size - 4, height: size - 4)

            // CRT scanline effect
            Canvas { context, canvasSize in
                for y in stride(from: CGFloat(0), to: canvasSize.height, by: 3) {
                    var line = Path()
                    line.move(to: CGPoint(x: 0, y: y))
                    line.addLine(to: CGPoint(x: canvasSize.width, y: y))
                    context.stroke(line, with: .color(phosphorGreen.opacity(0.03)), lineWidth: 1)
                }
            }
            .frame(width: width, height: height)
            .allowsHitTesting(false)

            // CRT phosphor glow (center)
            RoundedRectangle(cornerRadius: 4)
                .fill(
                    RadialGradient(
                        colors: [phosphorGreen.opacity(0.03), .clear],
                        center: .center, startRadius: 0, endRadius: size / 2
                    )
                )
                .frame(width: width, height: height)
                .allowsHitTesting(false)

            // Warm tube glow (off-center, upper)
            RoundedRectangle(cornerRadius: 4)
                .fill(
                    RadialGradient(
                        colors: [accentOrange.opacity(0.02), .clear],
                        center: .init(x: 0.5, y: 0.3), startRadius: 0, endRadius: size * 0.4
                    )
                )
                .frame(width: width, height: height)
                .allowsHitTesting(false)

            // CRT curvature vignette (dark corners)
            RoundedRectangle(cornerRadius: 4)
                .fill(
                    RadialGradient(
                        colors: [.clear, Color.black.opacity(0.06)],
                        center: .center, startRadius: size * 0.3, endRadius: size * 0.55
                    )
                )
                .frame(width: width, height: height)
                .allowsHitTesting(false)
        }
        .frame(width: width, height: height)
    }

    private func pixelCornerOffset(corner: Int) -> CGSize {
        let halfW = width / 2 - 9
        let halfH = height / 2 - 9
        switch corner {
        case 0: return CGSize(width: -halfW, height: -halfH)
        case 1: return CGSize(width: halfW, height: -halfH)
        case 2: return CGSize(width: -halfW, height: halfH)
        case 3: return CGSize(width: halfW, height: halfH)
        default: return .zero
        }
    }
}

// MARK: - Themed Completion Badge

struct ThemedCompletionBadge: View {
    var body: some View {
        let themeID = ThemeManager.shared.current.id
        switch themeID {
        case "synthwave":    SynthwaveCompletionBadge()
        case "mixtape":      MixtapeCompletionBadge()
        case "arcade":       ArcadeCompletionBadge()
        case "classicradio": ClassicRadioCompletionBadge()
        case "vumeter":      VUMeterCompletionBadge()
        default:             CleanCompletionBadge()
        }
    }
}

// MARK: Clean Completion Badge — glass checkmark circle

private struct CleanCompletionBadge: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.15), Color.white.opacity(0.05)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .frame(width: 52, height: 52)

            Circle()
                .stroke(Color.indigo.opacity(0.3), lineWidth: 2)
                .frame(width: 52, height: 52)

            Image(systemName: "checkmark")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.green, .mint],
                        startPoint: .top, endPoint: .bottom
                    )
                )
        }
    }
}

// MARK: Synthwave Completion Badge — neon trophy

private struct SynthwaveCompletionBadge: View {
    private let cyan = Color(red: 0.0, green: 0.96, blue: 1.0)
    private let amber = Color(red: 1.0, green: 0.84, blue: 0.0)

    var body: some View {
        ZStack {
            // Trophy icon with glow
            Image(systemName: "trophy.fill")
                .font(.system(size: 36))
                .foregroundStyle(
                    LinearGradient(
                        colors: [amber, Color(red: 1.0, green: 0.65, blue: 0.0)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .shadow(color: amber.opacity(0.5), radius: 6)

            // Cyan star overlay
            Image(systemName: "star.fill")
                .font(.system(size: 12))
                .foregroundColor(cyan)
                .shadow(color: cyan.opacity(0.6), radius: 4)
                .offset(y: -4)
        }
    }
}

// MARK: Mixtape Completion Badge — "REWIND COMPLETE" on green LCD

private struct MixtapeCompletionBadge: View {
    private let lcdGreen = Color(red: 0.22, green: 1.0, blue: 0.08)
    private let playerBlue = Color(red: 0.29, green: 0.42, blue: 0.60)

    var body: some View {
        VStack(spacing: 4) {
            Text("REWIND")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(playerBlue)

            Text("COMPLETE")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(lcdGreen)
                .shadow(color: lcdGreen.opacity(0.4), radius: 2)

            Image(systemName: "checkmark")
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundColor(lcdGreen)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(red: 0.06, green: 0.10, blue: 0.16))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(playerBlue, lineWidth: 1.5)
        )
    }
}

// MARK: Classic Radio Completion Badge — "SIDE A COMPLETE" tape label

private struct ClassicRadioCompletionBadge: View {
    private let cream = Color(red: 0.96, green: 0.90, blue: 0.78)
    private let brown = Color(red: 0.35, green: 0.29, blue: 0.20)
    private let amber = Color(red: 0.91, green: 0.63, blue: 0.19)

    var body: some View {
        VStack(spacing: 4) {
            Text("SIDE A")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(brown)

            Text("COMPLETE")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(amber)
                .shadow(color: amber.opacity(0.3), radius: 2)

            Image(systemName: "checkmark")
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundColor(amber)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(cream.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(brown, lineWidth: 1.5)
        )
    }
}

// MARK: VU Meter Completion Badge — "RECORDING DONE" amber on dark panel

private struct VUMeterCompletionBadge: View {
    private let amber = Color(red: 0.91, green: 0.63, blue: 0.19)
    private let darkPanel = Color(red: 0.07, green: 0.05, blue: 0.03)

    var body: some View {
        VStack(spacing: 4) {
            Text("RECORDING")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(amber.opacity(0.6))

            Text("DONE")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(amber)
                .shadow(color: amber.opacity(0.4), radius: 2)

            Image(systemName: "checkmark")
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundColor(amber)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(darkPanel)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(amber.opacity(0.4), lineWidth: 1.5)
        )
    }
}

// MARK: Arcade Completion Badge — "HIGH SCORE" CRT display

private struct ArcadeCompletionBadge: View {
    private let green = Color(red: 0.0, green: 1.0, blue: 0.0)
    private let orange = Color(red: 1.0, green: 0.67, blue: 0.0)

    var body: some View {
        VStack(spacing: 4) {
            Text("HIGH SCORE")
                .font(.system(size: 12, weight: .heavy, design: .monospaced))
                .foregroundColor(orange)
                .shadow(color: orange.opacity(0.4), radius: 2)

            HStack(spacing: 2) {
                Image(systemName: "star.fill").foregroundColor(.yellow)
                Image(systemName: "star.fill").foregroundColor(.cyan)
                Image(systemName: "star.fill").foregroundColor(.pink)
            }
            .font(.system(size: 8))

            Text("COMPLETE")
                .font(.system(size: 14, weight: .heavy, design: .monospaced))
                .foregroundColor(green)
                .shadow(color: green.opacity(0.5), radius: 3)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(red: 0.06, green: 0.06, blue: 0.14))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(green.opacity(0.5), lineWidth: 2)
        )
    }
}

// MARK: - Themed Control Button Style (watchOS only — uses watch-specific size tokens)

#if os(watchOS)
// Note: button style is watchOS-only; iOS uses standard button styles
struct ThemedControlButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        let themeID = ThemeManager.shared.current.id
        let effects = ThemeManager.shared.effects

        configuration.label
            .frame(width: ShuttlXSize.controlButtonDiameter, height: ShuttlXSize.controlButtonDiameter)
            .background(buttonBackground(themeID: themeID))
            .overlay(buttonOverlay(themeID: themeID, effects: effects))
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }

    @ViewBuilder
    private func buttonBackground(themeID: String) -> some View {
        switch themeID {
        case "synthwave":
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 0.08, green: 0.08, blue: 0.16))
        case "mixtape":
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(red: 0.08, green: 0.12, blue: 0.20))
        case "arcade":
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(red: 0.08, green: 0.08, blue: 0.2))
        case "classicradio":
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(red: 0.23, green: 0.18, blue: 0.12))
        case "vumeter":
            Circle()
                .fill(Color(red: 0.14, green: 0.11, blue: 0.07))
        default:
            RoundedRectangle(cornerRadius: 12)
                .fill(ShuttlXColor.watchButtonBackground)
        }
    }

    @ViewBuilder
    private func buttonOverlay(themeID: String, effects: ThemeEffects) -> some View {
        switch themeID {
        case "synthwave":
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(red: 0.0, green: 0.96, blue: 1.0).opacity(0.4), lineWidth: 1.5)
                .shadow(color: Color(red: 0.0, green: 0.96, blue: 1.0).opacity(0.3), radius: 4)
        case "mixtape":
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color(red: 0.29, green: 0.42, blue: 0.60), lineWidth: 1.5)
        case "arcade":
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color(red: 0.0, green: 1.0, blue: 0.0).opacity(0.4), lineWidth: 2)
        case "classicradio":
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color(red: 0.35, green: 0.29, blue: 0.20), lineWidth: 1.5)
        case "vumeter":
            Circle()
                .stroke(Color(red: 0.91, green: 0.63, blue: 0.19).opacity(0.4), lineWidth: 1.5)
        default:
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
        }
    }
}
#endif

// MARK: - Helper Shapes

private struct TickMark: View {
    let color: Color
    let length: CGFloat
    let width: CGFloat

    var body: some View {
        GeometryReader { geo in
            Rectangle()
                .fill(color)
                .frame(width: width, height: length)
                .position(x: geo.size.width / 2, y: length / 2)
        }
    }
}

private struct PixelCorner: View {
    let color: Color

    var body: some View {
        Canvas { context, size in
            let s = min(size.width, size.height) / 3
            // L-shaped bracket: 3 blocks each direction
            context.fill(Path(CGRect(x: 0, y: 0, width: s, height: s)), with: .color(color))
            context.fill(Path(CGRect(x: s, y: 0, width: s, height: s)), with: .color(color.opacity(0.7)))
            context.fill(Path(CGRect(x: 2 * s, y: 0, width: s, height: s)), with: .color(color.opacity(0.4)))
            context.fill(Path(CGRect(x: 0, y: s, width: s, height: s)), with: .color(color.opacity(0.7)))
            context.fill(Path(CGRect(x: 0, y: 2 * s, width: s, height: s)), with: .color(color.opacity(0.4)))
        }
    }
}

// MARK: New Helper Shapes

/// Tiny circle with cross line — used for screw decorations (Mixtape corners, VU Meter mounting)
private struct ScrewDecoration: View {
    let color: Color

    var body: some View {
        Canvas { context, size in
            let cx = size.width / 2
            let cy = size.height / 2
            let r = min(size.width, size.height) / 2

            // Outer circle
            context.stroke(
                Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)),
                with: .color(color), lineWidth: 0.5
            )
            // Cross lines
            var h = Path()
            h.move(to: CGPoint(x: cx - r * 0.6, y: cy))
            h.addLine(to: CGPoint(x: cx + r * 0.6, y: cy))
            context.stroke(h, with: .color(color), lineWidth: 0.5)

            var v = Path()
            v.move(to: CGPoint(x: cx, y: cy - r * 0.6))
            v.addLine(to: CGPoint(x: cx, y: cy + r * 0.6))
            context.stroke(v, with: .color(color), lineWidth: 0.5)
        }
    }
}

/// Canvas-based dot matrix grid — used for LCD textures (Mixtape) and sub-pixel patterns (Arcade)
private struct DotGrid: View {
    let color: Color
    let dotSize: CGFloat
    let spacing: CGFloat

    var body: some View {
        Canvas { context, size in
            let cols = Int(size.width / spacing)
            let rows = Int(size.height / spacing)
            let offsetX = (size.width - CGFloat(cols) * spacing) / 2
            let offsetY = (size.height - CGFloat(rows) * spacing) / 2

            for row in 0...rows {
                for col in 0...cols {
                    let x = offsetX + CGFloat(col) * spacing
                    let y = offsetY + CGFloat(row) * spacing
                    context.fill(
                        Path(ellipseIn: CGRect(x: x - dotSize / 2, y: y - dotSize / 2, width: dotSize, height: dotSize)),
                        with: .color(color)
                    )
                }
            }
        }
    }
}

/// Tape reel with hub and spoke lines — used for Classic Radio cassette label
private struct ReelHub: View {
    let color: Color
    let hubColor: Color

    var body: some View {
        Canvas { context, size in
            let cx = size.width / 2
            let cy = size.height / 2
            let outerR = min(size.width, size.height) / 2
            let hubR = outerR * 0.4

            // Outer circle
            context.stroke(
                Path(ellipseIn: CGRect(x: cx - outerR, y: cy - outerR, width: outerR * 2, height: outerR * 2)),
                with: .color(color), lineWidth: 1
            )

            // Hub circle
            context.stroke(
                Path(ellipseIn: CGRect(x: cx - hubR, y: cy - hubR, width: hubR * 2, height: hubR * 2)),
                with: .color(hubColor), lineWidth: 0.5
            )

            // 3 spokes at 120 degrees apart
            for i in 0..<3 {
                let angle = Double(i) * 120.0 * .pi / 180.0
                var spoke = Path()
                spoke.move(to: CGPoint(x: cx + cos(angle) * hubR, y: cy + sin(angle) * hubR))
                spoke.addLine(to: CGPoint(x: cx + cos(angle) * (outerR - 1), y: cy + sin(angle) * (outerR - 1)))
                context.stroke(spoke, with: .color(hubColor), lineWidth: 0.5)
            }
        }
    }
}
