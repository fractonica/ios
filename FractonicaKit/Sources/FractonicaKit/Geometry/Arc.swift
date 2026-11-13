import CFractonica

/// A circular arc (`frc_arc_t`): the one ornament of the instrument. Every
/// curve on screen is a carrier circle or an arc made from one by
/// ``child(m:local:odd:)`` (design/astrolabe/DESIGN.md §1, §5).
///
/// **The unit is the half-cycle.** Each half of a cycle is one arc, and the
/// two halves bulge to opposite sides, so a cycle is an S-shaped wave. A
/// half-cycle of level L carries `Level.factor` half-cycles of level L + 1,
/// standing on it and alternating outward / inward; every arc is the carrier
/// of the next:
///
///     // The focused cycle (level F) as a closed ring:
///     let carrier = Arc.fullCircle(cx: 196.5, cy: 277, radius: 102)
///     let slots = 2 * focus.factor                        // half-cycles of level F + 1
///     let child = carrier.child(m: slots, local: j, odd: j % 2 == 1)
///     // Half-cycles of level F + 2 on that child:
///     let m = focus.child!.factor
///     let grandchild = child.child(m: m, local: k, odd: (j * m + k) % 2 == 1)
///
/// `odd` is the parity of the child's global half-cycle index
/// (``Cycle/halfIndex``); even bulges outward. Which slot is being lit, and
/// how far, comes from ``Cycle/localHalfIndex`` and ``Cycle/halfProgress``
/// of the child level's running cycle: never from a multiplied phase.
///
/// Angles are radians measured like `atan2` with **y down** (screen
/// coordinates): 0 is 3 o'clock and a positive sweep runs clockwise.
public struct Arc: Hashable, Sendable {
    /// Centre.
    public var cx: Float
    public var cy: Float
    public var radius: Float
    /// Angle of the arc's first point.
    public var start: Float
    /// Signed angle travelled; negative is counter-clockwise.
    public var sweep: Float

    public init(cx: Float, cy: Float, radius: Float, start: Float, sweep: Float) {
        self.cx = cx
        self.cy = cy
        self.radius = radius
        self.start = start
        self.sweep = sweep
    }

    init(_ raw: frc_arc_t) {
        self.init(cx: raw.cx, cy: raw.cy, radius: raw.radius, start: raw.start, sweep: raw.sweep)
    }

    var raw: frc_arc_t { frc_arc_t(cx: cx, cy: cy, radius: radius, start: start, sweep: sweep) }

    /// π as the core's arc functions use it (`FRC_PI`). Swift's `Float.pi` is
    /// the float just BELOW π, the core's the one nearest to it: build arcs
    /// that the core will divide from this one, so that "half a turn" means
    /// the same on both sides.
    public static let pi: Float = FRC_PI

    /// A full-circle carrier that starts at 12 o'clock and runs clockwise:
    /// the focused cycle of the hero ring (DESIGN.md §5: start −π/2, sweep 2π).
    /// Give it `2 * factor` children (it needs at least 3).
    public static func fullCircle(cx: Float, cy: Float, radius: Float) -> Arc {
        Arc(cx: cx, cy: cy, radius: radius, start: -Arc.pi / 2, sweep: 2 * Arc.pi)
    }

    /// Level-0 "wave" root (`frc_arc_wave_root`): half-cycle `half` is a unit
    /// semicircle centred at `(2 * half + 1, 0)`, alternating above and below
    /// the axis. Scale and translate it in the view for the wave screen.
    public static func waveRoot(half: UInt32) -> Arc {
        Arc(frc_arc_wave_root(half))
    }

    /// Child `local` (0-based) of this arc divided into `m` slots
    /// (`frc_arc_child`): the circle through the two ends of its slot that
    /// meets this arc at right angles.
    /// - Parameters:
    ///   - m: number of slots, the parent level's factor (twice it on a
    ///     full-circle carrier). `m == 1` returns this arc unchanged.
    ///   - local: which slot, `0 ..< m`.
    ///   - odd: the bulge side: the parity of the child's global half-cycle index.
    /// - Returns: the empty arc (all fields zero, ``isEmpty``) when `m` is 0
    ///   or a slot would span π or more.
    public func child(m: Int, local: Int, odd: Bool) -> Arc {
        guard let m = UInt8(exactly: m), let local = UInt8(exactly: local) else {
            return Arc(cx: 0, cy: 0, radius: 0, start: 0, sweep: 0)
        }
        var parent = raw
        return Arc(frc_arc_child(&parent, m, local, odd ? 1 : 0))
    }

    /// The point at fraction `t` (0...1) along the arc (`frc_arc_point`):
    /// where the point of now sits on the arc being lit.
    public func point(at t: Float) -> (x: Float, y: Float) {
        var arc = raw
        var x: Float = 0
        var y: Float = 0
        frc_arc_point(&arc, t, &x, &y)
        return (x, y)
    }

    /// Whether this is the empty arc the core returns for an impossible child.
    public var isEmpty: Bool { radius == 0 && sweep == 0 }
}
