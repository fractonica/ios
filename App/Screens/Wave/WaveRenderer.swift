import SwiftUI
import FractonicaKit

/// The wave itself (DESIGN.md §7–9, "Timeline"; screen5.png): the cycles of
/// the focused level laid along a line, each half-cycle a semicircle
/// alternately above and below the axis and carrying its children as on the
/// instrument's ring; elapsed lit up to the fixed hairline; each cycle named
/// where it starts; and under it the rule with the four thresholds of the
/// cycle under the hairline, the next one lit.
///
/// Geometry is the core's (`Arc.waveRoot`, `Arc.child`); what is lit comes
/// from the running cycles the core returned (`NestRenderer.buildHalf`).
enum WaveRenderer {
    /// - Parameters:
    ///   - y: the wave's axis.
    ///   - quarterTimes: Earth mode: when each threshold falls.
    ///   - present: where the present is, in cycles from the hairline, while
    ///     the cursor is away from it.
    static func draw(
        _ reading: WaveReading, layout: WaveLayout, y: CGFloat, quarterTimes: [String]?, earth: Double,
        present: Double?, in ink: inout Ink
    ) {
        let palette = ink.palette, theme = ink.theme
        let k = layout.waveScale, width = layout.cycleWidth, radius = layout.halfRadius
        let hairline = layout.hairlineX
        let large = layout.layout == .desktop

        ink.text(reading.title, at: CGPoint(x: layout.left, y: y - 96 * k), theme.engraved(6.8, palette.ash))
        ink.text(reading.madeOf, at: CGPoint(x: layout.right, y: y - 96 * k), theme.engraved(6.8, palette.etch3),
                 anchor: .end)

        // Everything that moves is seen through the window (the desktop's
        // rail stays clear).
        var pane = ink
        let window = CGRect(x: layout.waveLeft, y: y - 120 * k, width: layout.waveRight - layout.waveLeft, height: 250 * k)
        if ink.pixelOrigin.x > 1 {
            // The view is wider than the design (an iPad upright, a wide Mac
            // window): the design's edge is then in the middle of the glass,
            // and the wave dies away towards it instead of being cut there.
            // The desktop's left edge is the rail, a border of its own.
            let run = 18 / max(window.width, 1)
            let ground = ink.palette.void
            let left = layout.layout == .desktop ? ground : ground.opacity(0)
            pane.context.clipToLayer { mask in
                mask.fill(Path(window), with: .linearGradient(
                    Gradient(stops: [
                        .init(color: left, location: 0), .init(color: ground, location: run),
                        .init(color: ground, location: 1 - run), .init(color: ground.opacity(0), location: 1),
                    ]),
                    startPoint: CGPoint(x: window.minX, y: 0), endPoint: CGPoint(x: window.maxX, y: 0)
                ))
            }
        } else {
            pane.context.clip(to: Path(window))
        }
        pane.line(from: CGPoint(x: layout.waveLeft, y: y), to: CGPoint(x: layout.waveRight, y: y),
                  palette.etch2, width: theme.line.engraving)

        // Where the cycle under the hairline starts.
        let live = reading.live
        let start = hairline - CGFloat(live?.cycle.phase.value ?? 0.5) * width
        // Outside the catalogue the wave is engraved: unnamed cycles to come.
        let offsets = live.map { $0.laps.map(\.offset) } ?? Array(-layout.reach ... layout.reach)

        var nest = NestRenderer.Nest()
        let carrierLit = CGMutablePath(), carrierRest = CGMutablePath()
        for offset in offsets {
            let x = start + CGFloat(offset) * width
            guard x + width > layout.waveLeft - 30, x < layout.waveRight + 30 else { continue }
            for half in 0 ..< 2 {
                let carrier = WaveArcs.half(half, radius: radius, origin: CGPoint(x: x, y: y))
                let stage = stage(of: half, offset: offset, running: live?.cycle)
                var progress: CGFloat = stage == .elapsed ? 1 : 0
                if stage == .current, let cycle = live?.cycle { progress = CGFloat(cycle.halfProgress.value) }
                carrier.addPath(to: carrierLit, from: 0, to: progress)
                carrier.addPath(to: carrierRest, from: progress, to: 1)
                let built = NestRenderer.buildHalf(
                    carrier: carrier, level: reading.focus, secondHalf: half == 1, stage: stage,
                    running: offset == 0 ? live?.nested : nil, depth: layout.depth
                )
                nest.merge(built)
            }
        }
        pane.stroke(carrierRest, palette.etch2, width: theme.line.engraving)
        pane.stroke(carrierLit, palette.lumenDim, width: theme.line.carrierLit)
        NestRenderer.paint(nest, heroWidth: large ? theme.line.heroDesktop : theme.line.heroPhone, in: &pane)

        // Each cycle is named where it starts.
        for lap in live?.laps ?? [] {
            let x = start + CGFloat(lap.offset) * width
            guard x > layout.waveLeft - 10, x < layout.waveRight + 10 else { continue }
            pane.line(from: CGPoint(x: x, y: y - 84 * k), to: CGPoint(x: x, y: y + 84 * k),
                      palette.etch2, width: theme.line.engraving, dash: [1, 3])
            let style = theme.value(large ? 13 : 11)
            let visible = edgeFade(from: x + 5, to: x + 5 + pane.width(of: lap.name, style), layout: layout)
            if visible > 0 {
                pane.text(lap.name, at: CGPoint(x: x + 5, y: y - 76 * k), style, opacity: visible)
            }
        }

        // The thresholds of the cycle under the hairline, on a rule below.
        let ruleY = y + 88 * k
        pane.line(from: CGPoint(x: layout.waveLeft, y: ruleY), to: CGPoint(x: layout.waveRight, y: ruleY),
                  palette.etch2, width: theme.line.engraving)
        if let live {
            for (index, quarter) in Quarter.allCases.enumerated() {
                let x = start + place(of: quarter) * width
                let isNext = live.next.quarter == quarter
                if quarter == .node {
                    pane.circle(CGPoint(x: x, y: y), radius: 2.4, fill: palette.void, stroke: palette.etch3, width: 0.9)
                }
                pane.line(from: CGPoint(x: x, y: ruleY), to: CGPoint(x: x, y: ruleY + 5),
                          isNext ? palette.lumen : palette.etch3, width: 1)
                let wordStyle = theme.engraved(large ? 6.5 : 5.8, isNext ? palette.lumen : palette.between, tracking: 0.18)
                let timeStyle = theme.earthText(large ? 8.5 : 7.5)
                let time = quarterTimes.flatMap { earth > 0 && index < $0.count ? $0[index] : nil }
                // A word and its time leave the window together.
                let half = max(pane.width(of: quarter.name, wordStyle), time.map { pane.width(of: $0, timeStyle) } ?? 0) / 2
                let visible = edgeFade(from: x - half, to: x + half, layout: layout)
                guard visible > 0 else { continue }
                pane.text(quarter.name, at: CGPoint(x: x, y: ruleY + 15), wordStyle, anchor: .middle, opacity: visible)
                if let time {
                    pane.text(time, at: CGPoint(x: x, y: ruleY + 26), timeStyle, anchor: .middle, opacity: earth * visible)
                }
            }
        }

        // The present, while the cursor is away from it: the NOW mark's own
        // sign, on the rule.
        if let present {
            let x = hairline + CGFloat(present) * width
            pane.circle(CGPoint(x: x, y: ruleY), radius: 3.6, fill: palette.void, stroke: palette.lumen, width: 0.9)
            pane.circle(CGPoint(x: x, y: ruleY), radius: 1.2, fill: palette.lumen)
        }

        // The cursor: a fixed hairline. Time moves under it.
        ink.line(from: CGPoint(x: hairline, y: y - 84 * k), to: CGPoint(x: hairline, y: y + 86 * k),
                 palette.bone, width: theme.line.hairline, opacity: 0.45)
        if let point = nest.nowPoint {
            Marks.nowPoint(at: point, radius: large ? 3.2 : 2.6, in: &ink)
        }
    }

    /// How visible a label that spans `from ... to` is: 1 inside the window,
    /// fading to 0 over the last points before an edge would cut it. Text
    /// carried along by time is never shown clipped; it rises as it enters.
    private static func edgeFade(from: CGFloat, to: CGFloat, layout: WaveLayout) -> Double {
        let run: CGFloat = 12, inset: CGFloat = 3
        let nearest = min(from - layout.waveLeft - inset, layout.waveRight - inset - to)
        return Double(min(max(nearest / run, 0), 1))
    }

    /// Where a half-cycle of the wave stands against the moment shown.
    private static func stage(of half: Int, offset: Int, running: Cycle?) -> NestRenderer.Stage {
        guard let running else { return .toCome }
        if offset != 0 { return offset < 0 ? .elapsed : .toCome }
        if running.isInSecondHalf { return half == 0 ? .elapsed : .current }
        return half == 0 ? .current : .toCome
    }

    /// Where a quarter ends along its cycle, 0...1: the quarter and the half
    /// of a cycle are the core's fractions (`FRC_FRAC_QUARTER`, `FRC_FRAC_HALF`).
    static func place(of quarter: Quarter) -> CGFloat {
        switch quarter {
        case .peak: return CGFloat(Fraction.quarter.value)
        case .node: return CGFloat(Fraction.half.value)
        case .valley: return CGFloat(Fraction.half.value + Fraction.quarter.value)
        case .end: return 1
        }
    }
}

extension NestRenderer.Nest {
    /// Adds another nest's arcs to this one, layer by layer, so that a row
    /// of carriers (the wave) is painted in one pass.
    mutating func merge(_ other: NestRenderer.Nest) {
        while layers.count < other.layers.count { layers.append(NestRenderer.Layer()) }
        for (index, layer) in other.layers.enumerated() {
            layers[index].elapsed.addPath(layer.elapsed)
            layers[index].toCome.addPath(layer.toCome)
            layers[index].nearElapsed.addPath(layer.nearElapsed)
            layers[index].nearToCome.addPath(layer.nearToCome)
            layers[index].pathElapsed.addPath(layer.pathElapsed)
            layers[index].pathToCome.addPath(layer.pathToCome)
        }
        if let point = other.nowPoint { nowPoint = point }
    }
}
