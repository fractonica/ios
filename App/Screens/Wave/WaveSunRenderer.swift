import SwiftUI
import FractonicaKit

/// The Sun's lane of the WAVE screen (DESIGN.md §7–9, "Timeline"): one solar
/// sync laid as a wave of its 19 Helions, lit up to the moment shown; the
/// four Pentads bracketed above it (the Hypopentad a square); the sync's
/// quarters named under it; and the window of the wave below marked on it.
/// Solar yellow, and nothing else is.
enum WaveSunRenderer {
    /// - Parameters:
    ///   - sun: `nil` in a partial sync or outside the catalogue: the lane
    ///     is then engraved and unlabelled.
    ///   - window: where the wave's window falls on the lane, in Helions
    ///     from the sync's start (may reach beyond the lane).
    ///   - quarterDates: Earth mode: the dates of the four quarters.
    static func draw(
        _ sun: WaveReading.SunLane?, layout: WaveLayout, y: CGFloat, window: ClosedRange<Double>?,
        quarterDates: [String]?, earth: Double, in ink: inout Ink
    ) {
        let palette = ink.palette, theme = ink.theme
        let x0 = layout.sunLeft, x1 = layout.sunRight
        let helion = layout.helionWidth, radius = helion / 4
        let halves = 2 * Sync.helions

        // The lane: two half-cycle arcs per Helion, lit through the running one.
        let lit = CGMutablePath(), rest = CGMutablePath()
        var point: CGPoint?
        let running = sun.map { 2 * $0.slot + ($0.helion.isInSecondHalf ? 1 : 0) }
        for half in 0 ..< halves {
            let arc = WaveArcs.half(half, radius: radius, origin: CGPoint(x: x0, y: y))
            guard let sun, let running else {
                arc.addPath(to: rest)
                continue
            }
            if half < running {
                arc.addPath(to: lit)
            } else if half == running {
                let progress = CGFloat(sun.helion.halfProgress.value)
                arc.addPath(to: lit, from: 0, to: progress)
                arc.addPath(to: rest, from: progress, to: 1)
                point = arc.cgPoint(at: progress)
            } else {
                arc.addPath(to: rest)
            }
        }
        ink.stroke(rest, palette.solDim, width: 1)
        ink.stroke(lit, palette.sol, width: 1.2, glow: 0.4)

        guard let sun else { return }
        ink.text("Solar sync \(sun.number)", at: CGPoint(x: layout.sunLeft - 2, y: y - 34),
                 theme.engraved(6.8, palette.solLabel))
        ink.text("Drift \(sun.drift)", at: CGPoint(x: layout.sunRight + 2, y: y - 34),
                 theme.engraved(6.8, palette.solLabel), anchor: .end)

        // The Pentads: a bracket over its Helions, the polygon and numeral in a gap.
        let bracketY = y - 13
        for (index, pentad) in sun.pentads.enumerated() {
            let color = index == sun.currentPentad ? palette.sol : palette.solDim
            let from = x0 + CGFloat(pentad.start) * helion + 2
            let to = x0 + CGFloat(pentad.start + pentad.helions) * helion - 2
            let bracket = CGMutablePath()
            bracket.move(to: CGPoint(x: from, y: bracketY + 4))
            bracket.addLine(to: CGPoint(x: from, y: bracketY))
            bracket.addLine(to: CGPoint(x: to, y: bracketY))
            bracket.addLine(to: CGPoint(x: to, y: bracketY + 4))
            ink.stroke(bracket, color, width: 0.9)
            let middle = (from + to) / 2
            ink.fill(CGPath(rect: CGRect(x: middle - 13, y: bracketY - 6, width: 26, height: 12), transform: nil),
                     palette.void)
            let hasNumeral = !pentad.numeral.isEmpty
            Marks.pentad(center: CGPoint(x: middle - (hasNumeral ? 5 : 0), y: bracketY + 0.5), radius: 4.6,
                         sides: pentad.helions, lit: nil, color: color, in: &ink)
            if hasNumeral {
                ink.text(pentad.numeral, at: CGPoint(x: middle + 3, y: bracketY + 3),
                         theme.engraved(7, color, tracking: 0.06))
            }
        }

        // The sync's quarters, a quarter of the lane each; the next one lit.
        for (index, quarter) in Quarter.allCases.enumerated() {
            let x = x0 + (x1 - x0) * CGFloat(index + 1) / CGFloat(Quarter.allCases.count)
            let isNext = sun.sync.next.quarter == quarter
            let color = isNext ? palette.sol : palette.solDim
            let anchor: TextAnchor = index == Quarter.allCases.count - 1 ? .end : .middle
            ink.line(from: CGPoint(x: x, y: y + 9), to: CGPoint(x: x, y: y + 14), color, width: 1)
            ink.text(quarter.name, at: CGPoint(x: x, y: y + 24), theme.engraved(6.2, color, tracking: 0.18),
                     anchor: anchor)
            if let quarterDates, earth > 0, index < quarterDates.count {
                ink.text(quarterDates[index], at: CGPoint(x: x, y: y + 35), theme.earthText(7.5),
                         anchor: anchor, opacity: earth)
            }
        }

        if let point { Marks.nowPoint(at: point, radius: 1.9, color: palette.sol, in: &ink) }

        // The window of the wave below, marked on the lane.
        if let window {
            let from = min(max(x0 + CGFloat(window.lowerBound) * helion, x0), x1)
            let to = min(max(x0 + CGFloat(window.upperBound) * helion, x0), x1)
            guard to > from || (window.lowerBound >= 0 && window.upperBound <= Double(Sync.helions)) else { return }
            let mark = CGMutablePath()
            mark.move(to: CGPoint(x: from, y: y + 6))
            mark.addLine(to: CGPoint(x: from, y: y + 9.5))
            mark.addLine(to: CGPoint(x: max(to, from + 1), y: y + 9.5))
            mark.addLine(to: CGPoint(x: max(to, from + 1), y: y + 6))
            ink.stroke(mark, palette.lumen, width: 0.9)
        }
    }
}
