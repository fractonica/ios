import CoreGraphics
import FractonicaKit
import XCTest

/// The drawing primitives: glyph outlines against SPEC §9.1 and arcs against
/// the `child()` formulas of design/astrolabe/DESIGN.md §5, which are typed in
/// here in double precision and compared with what the core returns.
final class GeometryTests: XCTestCase {
    // MARK: Glyphs

    func testGlyphStatesOfSection4_1() throws {
        XCTAssertEqual(Glyph.maxStrokes, 5)
        XCTAssertEqual((1 ... 5).map(Glyph.extreme(strokes:)), [1, 4, 13, 40, 121])
        XCTAssertEqual((1 ... 5).map(Glyph.stateCount(strokes:)), [4, 16, 52, 160, 484])
        XCTAssertEqual(Glyph.stateCount(strokes: 0), 0)
        XCTAssertThrows(.invalidArgument, try Glyph(index: 0, strokes: 6))

        // The 16 states of a 2-stroke glyph: up to +4, down through 0 to −4, back up.
        let states = try (0 ..< 16).map { try Glyph(index: $0, strokes: 2) }
        XCTAssertEqual(states.map(\.value), [0, 1, 2, 3, 4, 3, 2, 1, 0, -1, -2, -3, -4, -3, -2, -1])
        XCTAssertEqual(states.map(\.derivative), [1, 1, 1, 1, 0, -1, -1, -1, -1, -1, -1, -1, 0, 1, 1, 1])
        // Pitfall 5: the dot is on the falling branch only.
        XCTAssertEqual(states.map(\.isDotted), states.map { $0.derivative < 0 })
        for glyph in states {
            // Balanced ternary, least significant trit first: value = t0 + 3·t1.
            XCTAssertEqual(glyph.trits.count, 2)
            XCTAssertTrue(glyph.trits.allSatisfy { (-1 ... 1).contains($0) })
            XCTAssertEqual(glyph.trits[0] + 3 * glyph.trits[1], glyph.value)
            XCTAssertEqual(glyph.descending.index, (glyph.index + 8) % 16)
        }
        XCTAssertEqual(try Glyph(index: 16 + 5, strokes: 2).index, 5) // taken modulo 4M
        XCTAssertEqual(try Glyph(phase: .zero).index, 0)
        XCTAssertEqual(try Glyph(phase: .quarter).index, 4)
        XCTAssertEqual(try Glyph(phase: .half).index, 8)
        XCTAssertEqual(try Odometer(phase: .half, strokes: 2, digits: 2).digits, [8, 0])
        XCTAssertNil(try Odometer(phase: .half).nextChange)
    }

    /// SPEC §9.1, the table of paths, in hundredths of a design unit: the
    /// stem of every trit, then the stroke of every trit at its junction
    /// `y = 3i` (least significant trit at the top), then the dot.
    private func specPath(trits: [Int], dotted: Bool) -> [GlyphPathElement] {
        func p(_ x: Int, _ y: Int) -> GlyphPoint { GlyphPoint(x: x, y: y) }
        var path: [GlyphPathElement] = []
        for i in trits.indices {
            // stem: M 0 3i L 0 3i+3
            path += [.move(to: p(0, 300 * i)), .line(to: p(0, 300 * i + 300))]
        }
        for (i, trit) in trits.enumerated() {
            let y = 300 * i
            switch trit {
            case 0: // M -1 y L 1 y (horizontal bar)
                path += [.move(to: p(-100, y)), .line(to: p(100, y))]
            case 1: // M 0 y C 0 y 0 y+1 1 y+1 C 2 y+1 2 y 2 y (curve down and right)
                path += [
                    .move(to: p(0, y)),
                    .cubic(control1: p(0, y), control2: p(0, y + 100), to: p(100, y + 100)),
                    .cubic(control1: p(200, y + 100), control2: p(200, y), to: p(200, y)),
                ]
            default: // M 0 y C 0 y 0 y−1 −1 y−1 C −2 y−1 −2 y −2 y (curve up and left)
                path += [
                    .move(to: p(0, y)),
                    .cubic(control1: p(0, y), control2: p(0, y - 100), to: p(-100, y - 100)),
                    .cubic(control1: p(-200, y - 100), control2: p(-200, y), to: p(-200, y)),
                ]
            }
        }
        if dotted {
            // circle at (0, −1.75), radius 0.3, filled, only on dotted states
            path.append(.dot(center: p(0, -175), radius: 30))
        }
        return path
    }

    func testGlyphPath() throws {
        XCTAssertEqual(Glyph.unitsPerDesignUnit, 100)
        XCTAssertEqual(Glyph.inkThickness, 30) // "Ink thickness: 0.3"
        XCTAssertEqual(Glyph.dotRadius, 30)

        for strokes in 1 ... Glyph.maxStrokes {
            // "x ∈ [−2.15, 2.15] and y ∈ [−2.2, 3d + 0.15]"
            let box = Glyph.bounds(strokes: strokes)
            XCTAssertEqual(box, GlyphBounds(minX: -215, minY: -220, maxX: 215, maxY: 300 * strokes + 15))
            let half = Glyph.inkThickness / 2

            for index in 0 ..< Glyph.stateCount(strokes: strokes) {
                let glyph = try Glyph(index: index, strokes: strokes)
                let path = glyph.path
                XCTAssertEqual(path, specPath(trits: glyph.trits, dotted: glyph.isDotted),
                               "\(strokes) strokes, state \(index)")
                XCTAssertEqual(glyph.bounds, box)

                // The ink (every point, widened by half the thickness; the dot
                // by its radius) stays inside the bounds.
                for element in path {
                    let points: [GlyphPoint]
                    var margin = half
                    switch element {
                    case .move(let to), .line(let to): points = [to]
                    case .cubic(let control1, let control2, let to): points = [control1, control2, to]
                    case .dot(let center, let radius): points = [center]; margin = radius
                    }
                    for point in points {
                        XCTAssertTrue((box.minX + margin ... box.maxX - margin).contains(point.x), "\(point)")
                        XCTAssertTrue((box.minY + margin ... box.maxY - margin).contains(point.y), "\(point)")
                    }
                }

                // The flattened form: the same stems, each curve cut into pieces, no dot.
                let segments = glyph.segments(curveSteps: 4)
                let curves = glyph.trits.filter { $0 != 0 }.count
                let bars = glyph.trits.count - curves
                XCTAssertEqual(segments.count, strokes + bars + curves * 2 * 4)
                XCTAssertEqual(segments.first, GlyphSegment(
                    from: GlyphPoint(x: 0, y: 0), to: GlyphPoint(x: 0, y: 300)
                ))
            }
        }
        XCTAssertEqual(Glyph.bounds(strokes: 0), GlyphBounds(minX: 0, minY: 0, maxX: 0, maxY: 0))
    }

    func testGlyphOutlineInPoints() throws {
        let unit: CGFloat = 8.8 // DESIGN.md §6: the phone's centre odometer
        let origin = CGPoint(x: 100, y: 200)
        let glyph = try clock.glyph(Level(7)!, at: Vector.a) // 5 / +3 / dotted
        let outline = glyph.outline(unit: unit, origin: origin)

        XCTAssertEqual(outline.lineWidth, 0.3 * unit, accuracy: 1e-9)
        XCTAssertFalse(outline.strokes.isEmpty)
        XCTAssertFalse(outline.dots.isEmpty)
        // The dot: radius 0.3 u, centred 1.75 u above the top of the stem.
        let dot = outline.dots.boundingBoxOfPath
        XCTAssertEqual(dot.midX, origin.x, accuracy: 1e-6)
        XCTAssertEqual(dot.midY, origin.y - 1.75 * unit, accuracy: 1e-6)
        XCTAssertEqual(dot.width, 0.6 * unit, accuracy: 1e-6)
        // The box: x ±2.15 u, y −2.2 u … (3d + 0.15) u; centred on y = (3d − 2.05) / 2.
        XCTAssertEqual(outline.bounds.minX, origin.x - 2.15 * unit, accuracy: 1e-9)
        XCTAssertEqual(outline.bounds.width, 4.3 * unit, accuracy: 1e-9)
        XCTAssertEqual(outline.bounds.midY, origin.y + (3 * 2 - 2.05) / 2 * unit, accuracy: 1e-9)
        XCTAssertEqual(outline.bounds, Glyph.inkBounds(strokes: 2, unit: unit, origin: origin))
        // The stroked path stays inside the box; the stem spans 3 u per stroke.
        let ink = outline.strokes.boundingBoxOfPath
        XCTAssertTrue(outline.bounds.contains(ink))
        XCTAssertEqual(ink.minY, origin.y, accuracy: 1e-6)
        XCTAssertEqual(ink.maxY, origin.y + 6 * unit, accuracy: 1e-6)

        // A rising glyph has no dot.
        let rising = try clock.glyph(.helion, at: Vector.a).outline(unit: unit)
        XCTAssertTrue(rising.dots.isEmpty)
    }

    // MARK: Arcs

    /// DESIGN.md §5, `child(p, m, j, odd)`, in double precision.
    private func designChild(_ p: Arc, m: Int, j: Int, odd: Bool) -> (cx: Double, cy: Double, radius: Double, start: Double, sweep: Double) {
        let delta = Double(p.sweep) / Double(m)
        let mid = Double(p.start) + (Double(j) + 0.5) * delta
        let reach = Double(p.radius) / cos(delta / 2)
        let sign: Double = delta < 0 ? -1 : 1
        return (
            cx: Double(p.cx) + reach * cos(mid),
            cy: Double(p.cy) + reach * sin(mid),
            radius: Double(p.radius) * tan(abs(delta) / 2),
            start: mid - sign * (.pi / 2 + abs(delta) / 2),
            sweep: delta + (odd ? -.pi : .pi)
        )
    }

    private func assertArc(
        _ arc: Arc, matches expected: (cx: Double, cy: Double, radius: Double, start: Double, sweep: Double),
        _ message: String, file: StaticString = #filePath, line: UInt = #line
    ) {
        // Lengths are compared in points (rings are a few hundred points
        // wide); angles modulo a full turn.
        XCTAssertEqual(Double(arc.cx), expected.cx, accuracy: 2e-3, message, file: file, line: line)
        XCTAssertEqual(Double(arc.cy), expected.cy, accuracy: 2e-3, message, file: file, line: line)
        XCTAssertEqual(Double(arc.radius), expected.radius, accuracy: 2e-3, message, file: file, line: line)
        XCTAssertEqual(Double(arc.sweep), expected.sweep, accuracy: 1e-5, message, file: file, line: line)
        let turn = 2 * Double.pi
        let difference = (Double(arc.start) - expected.start).remainder(dividingBy: turn)
        XCTAssertEqual(difference, 0, accuracy: 1e-5, message, file: file, line: line)
    }

    func testHeroRingAgainstTheDesignFormulas() {
        // The phone's hero ring focused on the Helion: carrier at (196.5, 277), R 102.
        let carrier = Arc.fullCircle(center: CGPoint(x: 196.5, y: 277), radius: 102)
        XCTAssertEqual(Double(carrier.start), -Double.pi / 2, accuracy: 1e-7)
        XCTAssertEqual(Double(carrier.sweep), 2 * Double.pi, accuracy: 2e-7)
        XCTAssertEqual(Double(Arc.pi), Double.pi, accuracy: 1e-7)

        // 12 o'clock, clockwise: a quarter of the way round is 3 o'clock.
        XCTAssertEqual(Double(carrier.point(at: 0).x), 196.5, accuracy: 1e-3)
        XCTAssertEqual(Double(carrier.point(at: 0).y), 277 - 102, accuracy: 1e-3)
        XCTAssertEqual(Double(carrier.point(at: 0.25).x), 196.5 + 102, accuracy: 1e-3)
        XCTAssertEqual(Double(carrier.point(at: 0.25).y), 277, accuracy: 1e-3)
        XCTAssertEqual(Double(carrier.point(at: 0.5).y), 277 + 102, accuracy: 1e-3)

        for focus in Level.all.prefix(14) { // the focusable levels (ruling 9)
            let slots = 2 * focus.factor
            let inner = focus.child!.factor
            for j in 0 ..< slots {
                let child = carrier.child(m: slots, local: j, odd: j % 2 == 1)
                assertArc(child, matches: designChild(carrier, m: slots, j: j, odd: j % 2 == 1), "\(focus) child \(j)")
                XCTAssertFalse(child.isEmpty)

                // A child stands on its slot: it starts and ends on the carrier,
                // at the slot's two ends.
                let from = carrier.point(at: Float(j) / Float(slots))
                let to = carrier.point(at: Float(j + 1) / Float(slots))
                XCTAssertEqual(child.point(at: 0).x, from.x, accuracy: 2e-2)
                XCTAssertEqual(child.point(at: 0).y, from.y, accuracy: 2e-2)
                XCTAssertEqual(child.point(at: 1).x, to.x, accuracy: 2e-2)
                XCTAssertEqual(child.point(at: 1).y, to.y, accuracy: 2e-2)

                // Even bulges outward, odd inward: the middle of the arc is
                // outside / inside the carrier circle.
                let middle = child.point(at: 0.5)
                let distance = hypot(Double(middle.x) - 196.5, Double(middle.y) - 277)
                if j % 2 == 0 {
                    XCTAssertGreaterThan(distance, 102)
                } else {
                    XCTAssertLessThan(distance, 102)
                }

                for k in 0 ..< inner {
                    let odd = (j * inner + k) % 2 == 1
                    let grandchild = child.child(m: inner, local: k, odd: odd)
                    assertArc(grandchild, matches: designChild(child, m: inner, j: k, odd: odd), "\(focus) \(j).\(k)")
                }
            }
        }
    }

    func testChildEdgeCases() {
        let carrier = Arc.fullCircle(cx: 0, cy: 0, radius: 10)
        XCTAssertEqual(carrier.child(m: 1, local: 0, odd: false), carrier) // m == 1: the parent unchanged
        XCTAssertTrue(carrier.child(m: 0, local: 0, odd: false).isEmpty)
        XCTAssertTrue(carrier.child(m: 2, local: 0, odd: false).isEmpty) // a slot of π
        XCTAssertFalse(carrier.child(m: 3, local: 0, odd: false).isEmpty)
        XCTAssertTrue(carrier.child(m: 300, local: 0, odd: false).isEmpty) // not a factor the core takes
    }

    func testWaveRoot() {
        // "half-cycle `half` is a unit semicircle centred at (2*half + 1, 0),
        //  alternating above / below the axis."
        for half in 0 ..< 6 {
            let arc = Arc.waveRoot(half: UInt32(half))
            XCTAssertEqual(arc.cx, Float(2 * half + 1))
            XCTAssertEqual(arc.cy, 0)
            XCTAssertEqual(arc.radius, 1)
            XCTAssertEqual(abs(arc.sweep), Arc.pi)
            XCTAssertEqual(arc.point(at: 0).x, Float(2 * half), accuracy: 1e-5)
            XCTAssertEqual(arc.point(at: 0).y, 0, accuracy: 1e-5)
            XCTAssertEqual(arc.point(at: 1).x, Float(2 * half + 2), accuracy: 1e-5)
            XCTAssertEqual(arc.point(at: 1).y, 0, accuracy: 1e-5)
            XCTAssertEqual(abs(arc.point(at: 0.5).y), 1, accuracy: 1e-5)
        }
        // Consecutive halves bulge to opposite sides (y down: negative is above).
        let first = Arc.waveRoot(half: 0).point(at: 0.5).y
        let second = Arc.waveRoot(half: 1).point(at: 0.5).y
        XCTAssertEqual(first, -second, accuracy: 1e-5)
        XCTAssertLessThan(first, 0, "the first half-cycle rises: above the axis")
    }

    func testArcPathsForCoreGraphics() {
        let carrier = Arc.fullCircle(center: CGPoint(x: 196.5, y: 277), radius: 102)
        let child = carrier.child(m: 22, local: 3, odd: true)

        // A partial sweep starts and ends where the core says the arc is.
        for (from, to) in [(0.0, 1.0), (0.0, 0.37), (0.37, 1.0), (0.2, 0.6)] as [(CGFloat, CGFloat)] {
            for arc in [carrier, child] {
                let path = arc.cgPath(from: from, to: to)
                XCTAssertFalse(path.isEmpty)
                let end = arc.cgPoint(at: to)
                XCTAssertEqual(path.currentPoint.x, end.x, accuracy: 1e-3)
                XCTAssertEqual(path.currentPoint.y, end.y, accuracy: 1e-3)
                // The path stays on the arc's circle. Core Graphics draws an
                // arc as cubic curves, which stray from a true circle by up
                // to 0.027 % of the radius (0.03 pt on the hero ring).
                let box = path.boundingBoxOfPath
                let limit = CGFloat(arc.radius) * 1.0003 + 1e-3
                XCTAssertGreaterThanOrEqual(box.minX, arc.center.x - limit)
                XCTAssertLessThanOrEqual(box.maxX, arc.center.x + limit)
                XCTAssertGreaterThanOrEqual(box.minY, arc.center.y - limit)
                XCTAssertLessThanOrEqual(box.maxY, arc.center.y + limit)
            }
        }
        // The whole carrier is the whole circle.
        let circle = carrier.cgPath().boundingBoxOfPath
        XCTAssertEqual(circle.width, 204, accuracy: 0.07)
        XCTAssertEqual(circle.height, 204, accuracy: 0.07)
        // The first quarter of a clockwise ring from 12 o'clock is its upper right.
        let quarter = carrier.cgPath(from: 0, to: 0.25).boundingBoxOfPath
        XCTAssertEqual(quarter.minX, 196.5, accuracy: 0.04)
        XCTAssertEqual(quarter.maxX, 298.5, accuracy: 0.04)
        XCTAssertEqual(quarter.minY, 175, accuracy: 0.04)
        XCTAssertEqual(quarter.maxY, 277, accuracy: 0.04)

        // Elapsed + to come = the whole arc; nothing is drawn for an empty range or arc.
        XCTAssertTrue(child.cgPath(from: 0.4, to: 0.4).isEmpty)
        XCTAssertTrue(Arc(cx: 0, cy: 0, radius: 0, start: 0, sweep: 0).cgPath().isEmpty)
        let both = CGMutablePath()
        child.addPath(to: both, from: 0, to: 0.4)
        child.addPath(to: both, from: 0.4, to: 1)
        XCTAssertEqual(both.boundingBoxOfPath.width, child.cgPath().boundingBoxOfPath.width, accuracy: 1e-3)
    }

    // MARK: The ring is lit from the core's own half-cycles

    func testHalfCycleRecipes() throws {
        // At A the Helion ring (carrier = the running Helion) is lit through
        // the half-cycles of θ. θ's running cycle is local 7 of 9.
        let theta = try clock.cycle(Level(7)!, at: Vector.a)
        let helion = try clock.cycle(.helion, at: Vector.a)
        XCTAssertEqual(theta.local, 7)
        XCTAssertEqual(theta.localHalfIndex, 2 * 7 + (theta.isInSecondHalf ? 1 : 0))
        XCTAssertTrue((0 ..< 2 * Level.helion.factor).contains(theta.localHalfIndex))
        XCTAssertEqual(theta.halfIndex, 2 * theta.index + (theta.isInSecondHalf ? 1 : 0))
        // The local slot and the global half index agree through the parent's first child.
        let firstChild = try XCTUnwrap(helion.firstChildIndex)
        XCTAssertEqual(theta.halfIndex - 2 * firstChild, UInt64(theta.localHalfIndex))
        XCTAssertEqual(theta.parentIndex, helion.index)
        // θ is in its Node quarter (next threshold: node), so in its first half, past a quarter.
        XCTAssertEqual(theta.quarter, .node)
        XCTAssertFalse(theta.isInSecondHalf)
        XCTAssertGreaterThanOrEqual(theta.phase, .quarter)
        XCTAssertEqual(theta.halfProgress.value, 2 * theta.phase.value, accuracy: 1e-9)
        // The lit fraction of the whole ring, from slots, agrees with the Helion's own phase.
        let lit = (Double(theta.localHalfIndex) + theta.halfProgress.value) / Double(2 * Level.helion.factor)
        XCTAssertEqual(lit, helion.phase.value, accuracy: 1e-8)
    }

    func testHalfIndexInParentHalf() throws {
        // A half-cycle arc of level L carries the half-cycles of L + 1 that
        // fall in that half. The slot being lit on it is the child's local
        // half index counted from the start of the parent's running half.
        for instant in [Vector.a, Vector.b, Vector.c] {
            for index in 1 ... 16 {
                let level = Level(index)!
                let cycle = try clock.cycle(level, at: instant)
                let parent = try clock.cycle(level.parent!, at: instant)
                let slot = cycle.halfIndexInParentHalf
                XCTAssertTrue((0 ..< cycle.siblings).contains(slot), "\(level)")
                XCTAssertEqual(slot, cycle.localHalfIndex - (parent.isInSecondHalf ? cycle.siblings : 0), "\(level)")
                // The lit fraction of the parent's half agrees with the parent's own half progress.
                let lit = (Double(slot) + cycle.halfProgress.value) / Double(cycle.siblings)
                XCTAssertEqual(lit, parent.halfProgress.value, accuracy: 1e-7, "\(level)")
            }
        }
    }
}
