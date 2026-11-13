import SwiftUI
import FractonicaKit

/// The spine of the LADDER (DESIGN.md §8): the whole ladder at the right
/// edge. 63 ticks, the unit rungs lettered, the window of the wheel bracketed
/// in lumen, the instrument's focus ringed. It is also a scrubber
/// (`LadderScreen` takes the touches).
enum LadderSpine {
    /// What the spine shows of one rung: all of it static, read once.
    struct Mark: Equatable, Sendable {
        let name: String
        let isUnit: Bool
        let hasBand: Bool
        let isVisibleLight: Bool

        static func read(interval: SarosInterval) -> [Mark] {
            Level.all.map { level in
                let band = level.band(interval)
                return Mark(name: level.name, isUnit: level.unit != nil, hasBand: band != .noBand,
                            isVisibleLight: band == .visible)
            }
        }
    }

    /// - Parameters:
    ///   - position: the scale position at the wheel's middle (fractional
    ///     while it turns).
    ///   - focus: the level the instrument is focused on.
    static func draw(
        _ marks: [Mark], geometry g: LadderGeometry, position: Double, focus: Level, in ink: inout Ink
    ) {
        let palette = ink.palette, theme = ink.theme
        let x = g.spineX
        for (index, mark) in marks.enumerated() {
            let y = g.spineY(Double(index))
            // The rung that is visible light keeps its red here too.
            let color = mark.isVisibleLight ? palette.hAlpha
                : (mark.isUnit ? palette.ash : (mark.hasBand ? palette.etch3 : palette.etch2))
            ink.line(from: CGPoint(x: x - (mark.isUnit ? 7 : 3.5), y: y), to: CGPoint(x: x, y: y),
                     color, width: mark.isVisibleLight ? 1.6 : theme.line.tick)
            if mark.isUnit {
                ink.text(mark.name, at: CGPoint(x: x - 11, y: y + 2.6), theme.letter(7.5, palette.ash), anchor: .end)
            }
        }
        // The window of the wheel: a bracket around the rungs in view, with
        // a notch at the rung in the middle.
        let last = Double(Level.count - 1)
        let top = g.spineY(max(position - Double(g.span), 0)) - 4
        let bottom = g.spineY(min(position + Double(g.span), last)) + 4
        let bracket = CGMutablePath()
        bracket.move(to: CGPoint(x: x + 3, y: top))
        bracket.addLine(to: CGPoint(x: x + 7, y: top))
        bracket.addLine(to: CGPoint(x: x + 7, y: bottom))
        bracket.addLine(to: CGPoint(x: x + 3, y: bottom))
        let middle = g.spineY(min(max(position, 0), last))
        bracket.move(to: CGPoint(x: x + 7, y: middle))
        bracket.addLine(to: CGPoint(x: x + 10, y: middle))
        ink.stroke(bracket, palette.lumen, width: theme.line.sigil)
        // The level the instrument is focused on.
        ink.circle(CGPoint(x: x - 22, y: g.spineY(Double(focus.index))), radius: 2.6, stroke: palette.lumen, width: 0.9)
    }
}
