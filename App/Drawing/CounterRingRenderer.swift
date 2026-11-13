import SwiftUI
import FractonicaKit

/// A counter ring (DESIGN.md §5): one plain ring for one level, cut into its
/// children as slots, lit through the current one, carrying one "planet" at
/// the level's phase. The Sun's ring is the same object with 19 slots and
/// wider gaps before each Pentad.
enum CounterRingRenderer {
    /// How a ring is painted.
    struct Style {
        var width: CGFloat
        /// Completed slots / the lit part of the current slot / what is left.
        var lit: Color
        var current: Color
        var rest: Color
        var planet: Color
        var planetRadius: CGFloat
        var planetGlow: Double
        var letterColor: Color
        var letterSize: CGFloat
        /// How far along the ring past the planet its letter sits, in points.
        var letterOffset: CGFloat
        /// Gap between slots, in points along the ring.
        var gap: CGFloat = 3.2
    }

    /// The style of an ancestor's ring: the four major periods are engraved
    /// more faintly than the minor levels.
    static func style(major: Bool, metrics: InstrumentMetrics, theme: Theme) -> Style {
        let palette = theme.palette, large = metrics.isLarge
        return Style(
            width: major ? theme.line.counterMajor : theme.line.counterMinor,
            lit: major ? palette.lumenEtch : palette.lumenDim,
            current: major ? palette.lumenMajor : palette.lumenMid,
            rest: palette.etch2,
            planet: major ? palette.lumenMid : palette.lumen,
            planetRadius: major ? (large ? 2 : 1.6) : (large ? 2.4 : 1.9),
            planetGlow: theme.glow.planet,
            letterColor: major ? palette.majorLabel : palette.ash,
            letterSize: metrics.ringLetterSize,
            letterOffset: metrics.ringLetterOffset
        )
    }

    /// The style of the Sun's ring.
    static func sunStyle(metrics: InstrumentMetrics, theme: Theme) -> Style {
        let palette = theme.palette
        return Style(
            width: theme.line.counterMinor, lit: palette.solDim, current: palette.sol, rest: palette.solEmpty,
            planet: palette.sol, planetRadius: metrics.isLarge ? 2.6 : 2.1, planetGlow: theme.glow.planet,
            letterColor: palette.sol, letterSize: metrics.ringLetterSize, letterOffset: metrics.ringLetterOffset,
            gap: 2.4
        )
    }

    /// Draws a ring.
    /// - Parameters:
    ///   - slots: how many slots the ring is cut into, starting at 12 o'clock.
    ///   - currentSlot: the slot being lit (slots before it are complete);
    ///     `nil` leaves the whole ring engraved, without a planet.
    ///   - slotFill: how much of the current slot is lit, 0...1.
    ///   - planetPhase: the ring's own phase, 0...1: where the planet sits.
    ///   - groupStarts: slots that begin a group and get a wider gap before
    ///     them (the Pentads on the Sun's ring).
    ///   - letter: the level's letter beside the planet; `nil` for none.
    static func draw(
        center: CGPoint, radius: CGFloat, slots: Int, currentSlot: Int?, slotFill: Double,
        planetPhase: Double, groupStarts: [Int] = [], letter: String?, style: Style, in ink: inout Ink
    ) {
        guard slots > 0, radius > 0 else { return }
        let gap = style.gap / radius
        let slotAngle = 2 * CGFloat.pi / CGFloat(slots)
        let lit = CGMutablePath(), current = CGMutablePath(), rest = CGMutablePath()
        for slot in 0 ..< slots {
            let extra = groupStarts.contains(slot) ? gap * 1.4 : 0
            let arc = Arc(
                cx: Float(center.x), cy: Float(center.y), radius: Float(radius),
                start: Float(-CGFloat.pi / 2 + CGFloat(slot) * slotAngle + gap / 2 + extra),
                sweep: Float(slotAngle - gap - extra)
            )
            guard let currentSlot else {
                arc.addPath(to: rest)
                continue
            }
            if slot < currentSlot {
                arc.addPath(to: lit)
            } else if slot > currentSlot {
                arc.addPath(to: rest)
            } else {
                let fill = CGFloat(min(max(slotFill, 0), 1))
                arc.addPath(to: current, from: 0, to: fill)
                arc.addPath(to: rest, from: fill, to: 1)
            }
        }
        ink.stroke(rest, style.rest, width: style.width)
        ink.stroke(lit, style.lit, width: style.width)
        ink.stroke(current, style.current, width: style.width * ink.theme.line.currentSlotFactor)

        guard currentSlot != nil else { return }
        // The planet, knocked out of the ring by a stroke of the void.
        let angle = -CGFloat.pi / 2 + CGFloat(planetPhase) * 2 * .pi
        let planet = center.polar(radius, angle)
        ink.circle(planet, radius: style.planetRadius, fill: style.planet, glow: style.planetGlow)
        ink.circle(planet, radius: 3.4, stroke: ink.palette.void, width: 1.4)
        ink.circle(planet, radius: style.planetRadius, fill: style.planet)
        if let letter {
            let letterAngle = angle + style.letterOffset / radius
            let position = center.polar(radius, letterAngle)
            ink.text(
                letter, at: CGPoint(x: position.x, y: position.y + style.letterSize * 0.34),
                ink.theme.letter(style.letterSize, style.letterColor), anchor: .middle, knockout: 3.5
            )
        }
    }
}
