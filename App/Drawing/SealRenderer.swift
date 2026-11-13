import SwiftUI
import FractonicaKit

/// A level's seal: its ring in miniature (DESIGN.md §5, "Seals"). The carrier
/// and its `2 × factor` first-level arcs, scaled so that the outer extent is
/// constant. It is the icon of a level wherever a level is listed (ladder
/// rows, the lens's lineage strip): β and γ1 look different because 13 ≠ 5.
enum SealRenderer {
    /// Draws the seal of `level` inside a circle of radius `extent`.
    /// - Parameters:
    ///   - extent: the outer extent in points (11 in a list, 30 when focused).
    ///   - glow: opacity of a glow under the arcs (`nil`: none).
    /// - Returns: the carrier's radius, for callers that add marks to it.
    @discardableResult
    static func draw(
        _ level: Level, center: CGPoint, extent: CGFloat, color: Color,
        width: CGFloat = 0.8, opacity: Double = 1, glow: Double? = nil, in ink: inout Ink
    ) -> CGFloat {
        let slots = 2 * level.factor
        // The outward arcs reach the carrier's radius times a factor that
        // depends on the slot count only; measure it on a unit carrier with
        // the core's own construction and scale to the wanted extent.
        let unit = Arc.fullCircle(cx: 0, cy: 0, radius: 1).child(m: slots, local: 0, odd: false)
        let reach = CGFloat((unit.cx * unit.cx + unit.cy * unit.cy).squareRoot() + unit.radius)
        let radius = reach > 0 ? extent / reach : extent
        let carrier = Arc.fullCircle(center: center, radius: radius)
        let arcs = CGMutablePath()
        for slot in 0 ..< slots {
            carrier.child(m: slots, local: slot, odd: slot % 2 == 1).addPath(to: arcs)
        }
        ink.circle(center, radius: radius, stroke: color, width: ink.theme.line.hairline, opacity: 0.35 * opacity)
        ink.stroke(arcs, color, width: width, opacity: opacity, glow: glow)
        return radius
    }
}
