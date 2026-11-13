import SwiftUI
import FractonicaKit

/// The small marks of the instrument and its panels: the point of now, bead
/// counters, the Pentad polygon, the quarter mark, the Earth sign of the mode
/// toggle. Each is a few strokes from the mockup's drawing kit.
enum Marks {
    /// The point of now: a disc with glow, a white core and a hairline halo
    /// (DESIGN.md §5). It never pulses.
    /// - Parameter color: `nil` is the cold light; the Sun's lane passes its own.
    static func nowPoint(at point: CGPoint, radius: CGFloat, color: Color? = nil, in ink: inout Ink) {
        let color = color ?? ink.palette.now
        ink.circle(point, radius: radius * 2.6, stroke: color, width: 0.6, opacity: 0.55)
        ink.circle(point, radius: radius, fill: color, glow: ink.theme.glow.now)
        ink.circle(point, radius: radius * 0.45, fill: ink.palette.nowCore)
    }

    /// A sibling counter laid straight (SPEC §6.1): `count` beads centred on
    /// `center`, lit through bead `local`.
    /// - Parameter fresh: how far the newest lit bead has turned from hollow
    ///   to lit, 0...1 (a completing child fades in over 400 ms).
    static func beads(
        center: CGPoint, count: Int, local: Int?, pitch: CGFloat = 9, color: Color? = nil,
        fresh: Double = 1, in ink: inout Ink
    ) {
        let color = color ?? ink.palette.lumen
        for bead in 0 ..< count {
            let position = CGPoint(x: center.x + (CGFloat(bead) - CGFloat(count - 1) / 2) * pitch, y: center.y)
            let lit: Double = local.map { bead < $0 ? 1 : (bead == $0 ? fresh : 0) } ?? 0
            if lit < 1 {
                ink.circle(position, radius: 1.6, fill: ink.palette.void, stroke: ink.palette.etch3, width: 0.8)
            }
            if lit > 0 {
                ink.circle(position, radius: 1.9, fill: color, stroke: color, width: 0.8, opacity: lit)
            }
        }
    }

    /// The Pentad mark: a pentagon whose vertices count its Helions, lit
    /// through the running one. The Hypopentad (four Helions) is a square
    /// (design/README.md ruling 10).
    /// - Parameter lit: vertices to light; `nil` draws the bare polygon.
    /// - Parameter color: `nil` is the Sun's colour; a Pentad that is not
    ///   the running one is drawn in the dimmed one.
    static func pentad(center: CGPoint, radius: CGFloat, sides: Int, lit: Int?, color: Color? = nil, in ink: inout Ink) {
        guard sides >= 3 else { return }
        let color = color ?? ink.palette.sol
        let turn = sides == 4 ? CGFloat.pi / 4 : 0
        let vertices = (0 ..< sides).map { index in
            center.polar(radius, -CGFloat.pi / 2 + CGFloat(index) * 2 * .pi / CGFloat(sides) + turn)
        }
        let outline = CGMutablePath()
        outline.addLines(between: vertices)
        outline.closeSubpath()
        ink.stroke(outline, color, width: 0.9)
        guard let lit else { return }
        for (index, vertex) in vertices.enumerated() {
            let isLit = index < lit
            ink.circle(vertex, radius: isLit ? 1.9 : 1.5, fill: isLit ? color : ink.palette.void, stroke: color, width: 0.7)
        }
    }

    /// Where on a ring a threshold sits: a small circle with a dot at the
    /// quarter's place (end 12, peak 3, node 6, valley 9 o'clock).
    static func quarter(_ quarter: Quarter, center: CGPoint, color: Color, in ink: inout Ink) {
        ink.circle(center, radius: 5, stroke: ink.palette.etch3, width: 0.8)
        ink.circle(center.polar(5, angle(of: quarter)), radius: 1.9, fill: color)
    }

    /// The angle of a threshold on a ring that starts at 12 o'clock and runs
    /// clockwise: a quarter of a turn per quarter, the End back at the top.
    static func angle(of quarter: Quarter) -> CGFloat {
        switch quarter {
        case .peak: return 0
        case .node: return .pi / 2
        case .valley: return .pi
        case .end: return -.pi / 2
        }
    }

    /// The mode toggle's sign: an empty ring in pure mode; in Earth mode the
    /// ring gains its cross and becomes the Earth symbol.
    /// - Parameter earth: 0 pure ... 1 Earth (cross-faded over 200 ms).
    static func modeSign(center: CGPoint, earth: Double, in ink: inout Ink) {
        let radius: CGFloat = 7.5, width = ink.theme.line.sigil
        ink.circle(center, radius: radius, stroke: ink.palette.etch3, width: width, opacity: 1 - earth)
        ink.circle(center, radius: radius, stroke: ink.palette.bone, width: width, opacity: earth)
        let cross = CGMutablePath()
        cross.move(to: CGPoint(x: center.x - radius, y: center.y))
        cross.addLine(to: CGPoint(x: center.x + radius, y: center.y))
        cross.move(to: CGPoint(x: center.x, y: center.y - radius))
        cross.addLine(to: CGPoint(x: center.x, y: center.y + radius))
        ink.stroke(cross, ink.palette.bone, width: width, opacity: earth)
    }

    /// The Earth sign as furniture: a small ring with its cross, heading a
    /// column that is wholly Earth units (DESIGN.md §9, "the ⊕ rule"). In a
    /// line of text the sign is a character (`Ink.earth`).
    static func earthSign(center: CGPoint, opacity: Double = 1, in ink: inout Ink) {
        guard opacity > 0 else { return }
        let color = ink.palette.etch3, radius: CGFloat = 3.4
        let cross = CGMutablePath()
        cross.move(to: CGPoint(x: center.x - radius, y: center.y))
        cross.addLine(to: CGPoint(x: center.x + radius, y: center.y))
        cross.move(to: CGPoint(x: center.x, y: center.y - radius))
        cross.addLine(to: CGPoint(x: center.x, y: center.y + radius))
        ink.circle(center, radius: radius, stroke: color, width: ink.theme.line.tick, opacity: opacity)
        ink.stroke(cross, color, width: ink.theme.line.engraving, opacity: opacity)
    }

    /// A rule that fades out towards both ends (the registers of the panels).
    static func fadingRule(from start: CGPoint, to end: CGPoint, in ink: inout Ink) {
        let color = ink.palette.etch2
        let path = CGMutablePath()
        path.move(to: start)
        path.addLine(to: end)
        ink.stroke(path, fading: [
            .init(color: color.opacity(0), location: 0), .init(color: color, location: 0.15),
            .init(color: color, location: 0.85), .init(color: color.opacity(0), location: 1),
        ], from: start, to: end, width: ink.theme.line.engraving)
    }
}
