#if canImport(CoreGraphics)
import CoreGraphics

extension Arc {
    /// A full-circle carrier from Core Graphics values; see
    /// ``fullCircle(cx:cy:radius:)``.
    public static func fullCircle(center: CGPoint, radius: CGFloat) -> Arc {
        fullCircle(cx: Float(center.x), cy: Float(center.y), radius: Float(radius))
    }

    /// The centre as a `CGPoint`.
    public var center: CGPoint { CGPoint(x: CGFloat(cx), y: CGFloat(cy)) }

    /// The point at fraction `t` along the arc, from the core (``point(at:)``).
    public func cgPoint(at t: CGFloat) -> CGPoint {
        let p = point(at: Float(t))
        return CGPoint(x: CGFloat(p.x), y: CGFloat(p.y))
    }

    /// The part of the arc between two fractions as a path, for stroking:
    /// `cgPath(from: 0, to: p)` is the elapsed part, `cgPath(from: p, to: 1)`
    /// what is still to come.
    public func cgPath(from: CGFloat = 0, to: CGFloat = 1) -> CGPath {
        let path = CGMutablePath()
        addPath(to: path, from: from, to: to)
        return path
    }

    /// Appends the same part to `path`, starting a new subpath, so that many
    /// arcs of one style can be stroked in one call.
    ///
    /// The arc is handed to Core Graphics as what it is (centre, radius,
    /// start angle, signed delta), in the parametrisation of `frc_arc_point`:
    /// fraction `t` is the angle `start + sweep * t`. In a y-down space (a
    /// SwiftUI `Canvas`) a positive delta runs clockwise, as in the design.
    public func addPath(to path: CGMutablePath, from: CGFloat = 0, to: CGFloat = 1) {
        guard !isEmpty, to != from else { return }
        let sweep = CGFloat(self.sweep)
        path.move(to: cgPoint(at: from))
        path.addRelativeArc(
            center: center,
            radius: CGFloat(radius),
            startAngle: CGFloat(start) + sweep * from,
            delta: sweep * (to - from)
        )
    }
}
#endif
