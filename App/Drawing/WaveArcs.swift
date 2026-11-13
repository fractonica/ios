import CoreGraphics
import FractonicaKit

/// The wave laid along a line: the core's unit semicircles
/// (`Arc.waveRoot(half:)`: half-cycle `h` is a semicircle of radius 1
/// centred at `(2h + 1, 0)`, alternately above and below the axis) brought
/// to a place and a size on screen. Only a scale and a translation happen
/// here; the shape, the side each half bulges to and the direction it runs
/// in are the core's.
enum WaveArcs {
    /// Half-cycle `half` of a wave whose half-cycles have `radius` points
    /// and whose half 0 starts at `origin` on the axis.
    static func half(_ half: Int, radius: CGFloat, origin: CGPoint) -> Arc {
        let unit = Arc.waveRoot(half: UInt32(max(half, 0)))
        return Arc(
            cx: Float(origin.x) + Float(radius) * unit.cx, cy: Float(origin.y) + Float(radius) * unit.cy,
            radius: Float(radius) * unit.radius, start: unit.start, sweep: unit.sweep
        )
    }
}
