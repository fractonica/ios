import FractonicaKit
import XCTest

/// The edges of the clock's domain: outside the catalogue nothing is read and
/// nothing is extrapolated (SPEC §2.2; design/README.md, ruling 7), and at
/// the closing instant nothing comes "next".
final class CatalogueEdgeTests: XCTestCase {
    private var before: Instant { clock.first.advanced(byMicroseconds: -1) }
    private var after: Instant { clock.last.advanced(byMicroseconds: 1) }

    func testDomain() throws {
        // "Solar Saros 141: 70 eclipses, 1613-05-19 .. 2857-06-13"
        XCTAssertEqual(CivilTime(clock.first).year, 1613)
        XCTAssertEqual(CivilTime(clock.first).month, 5)
        XCTAssertEqual(CivilTime(clock.first).day, 19)
        XCTAssertEqual(CivilTime(clock.last).year, 2857)
        XCTAssertEqual(CivilTime(clock.last).month, 6)
        XCTAssertEqual(CivilTime(clock.last).day, 13)
        XCTAssertEqual(clock.eclipse(0), clock.first)
        XCTAssertEqual(clock.eclipse(clock.eclipseCount - 1), clock.last)
        XCTAssertNil(clock.eclipse(clock.eclipseCount))
        XCTAssertNil(clock.eclipse(-1))
        XCTAssertEqual(clock.range, clock.first ... clock.last)

        XCTAssertTrue(clock.contains(clock.first))
        XCTAssertTrue(clock.contains(clock.last))
        XCTAssertTrue(clock.contains(Vector.a))
        XCTAssertFalse(clock.contains(before))
        XCTAssertFalse(clock.contains(after))

        // "time travel clamps to the catalogue"
        XCTAssertEqual(clock.clamped(before), clock.first)
        XCTAssertEqual(clock.clamped(after), clock.last)
        XCTAssertEqual(clock.clamped(Vector.a), Vector.a)
        XCTAssertEqual(clock.clamped(Instant(microseconds: .min + 1)), clock.first)
        XCTAssertEqual(clock.clamped(Instant(microseconds: .max)), clock.last)
    }

    func testEveryReadingIsRefusedOutside() {
        for instant in [before, after, Instant(microseconds: 0).advanced(byMicroseconds: -40_000_000_000_000_000)] {
            XCTAssertThrows(.outOfRange, try clock.position(at: instant))
            XCTAssertThrows(.outOfRange, try clock.cycle(.helion, at: instant))
            XCTAssertThrows(.outOfRange, try clock.nextThreshold(.helion, after: instant))
            XCTAssertThrows(.outOfRange, try clock.glyph(.helion, at: instant))
            XCTAssertThrows(.outOfRange, try clock.odometer(.helion, at: instant))
            XCTAssertThrows(.outOfRange, try clock.sync(at: instant))
            XCTAssertThrows(.outOfRange, try clock.syncOdometer(at: instant))
            XCTAssertThrows(.outOfRange, try clock.pentad(at: instant))
            XCTAssertThrows(.outOfRange, try clock.date(at: instant))
            XCTAssertThrows(.outOfRange, try clock.interval(at: instant))
            XCTAssertThrows(.outOfRange, try clock.span(from: instant, to: Vector.a))
            XCTAssertThrows(.outOfRange, try clock.span(from: Vector.a, to: instant))
            XCTAssertThrows(.outOfRange, try clock.instant(byStepping: .helion, by: 1, from: instant))
        }
    }

    func testArgumentErrorsWinOverRangeErrors() {
        // A level the clock does not read, asked outside the catalogue: the argument is reported.
        let deep = Level(22)!
        XCTAssertFalse(deep.isClockLevel)
        XCTAssertThrows(.invalidArgument, try clock.cycle(deep, at: before))
        XCTAssertThrows(.invalidArgument, try clock.cycle(deep, at: Vector.a))
        XCTAssertThrows(.invalidArgument, try clock.odometer(.helion, at: before, strokes: 6))
        XCTAssertThrows(.invalidArgument, try clock.odometer(.helion, at: Vector.a, digits: 5))
        XCTAssertThrows(.invalidArgument, try clock.odometer(.helion, at: Vector.a, strokes: 0))
        XCTAssertThrows(.invalidArgument, try clock.glyph(.helion, at: Vector.a, strokes: 300))
        XCTAssertEqual(clock.cycleCount(deep), 0)
    }

    func testTheOpeningInstant() throws {
        let date = try clock.date(at: clock.first)
        XCTAssertEqual(date.stamp, "α#1 β#1 γ#1 δ#1 ε#1 1η 0ι 0λ 0ν")
        for level in Level.clockLevels {
            let cycle = try clock.cycle(level, at: clock.first)
            XCTAssertEqual(cycle.index, 0, "\(level)")
            XCTAssertEqual(cycle.start, clock.first, "\(level)")
            XCTAssertEqual(cycle.phase, .zero, "\(level)")
            XCTAssertEqual(cycle.quarter, .peak, "\(level)")
            XCTAssertEqual(try clock.odometer(level, at: clock.first).digits, [0, 0], "\(level)")
        }
        // The first sync is partial: no sync reading, but its Pentad answers.
        XCTAssertThrows(.outOfRange, try clock.sync(at: clock.first))
        XCTAssertNoThrow(try clock.pentad(at: clock.first))
        XCTAssertEqual(try clock.position(at: clock.first).ordinal, 0)
        XCTAssertEqual(try clock.position(at: clock.first).numerator, 0)
        XCTAssertEqual(clock.instant(atPosition: 0, over: 1), clock.first)
    }

    func testTheClosingInstant() throws {
        let last = clock.last
        // It belongs to the last cycle, which is clipped there: instant == end.
        for level in Level.clockLevels where level.index <= 18 {
            let cycle = try clock.cycle(level, at: last)
            XCTAssertEqual(cycle.end, last, "\(level)")
            XCTAssertEqual(cycle.index, clock.cycleCount(level) - 1, "\(level)")
            // Nothing comes later: no next threshold, no next odometer change.
            let next = try clock.nextThreshold(level, after: last)
            XCTAssertNil(next.instant, "\(level)")
            XCTAssertNil(try clock.odometer(level, at: last).nextChange, "\(level)")
        }
        XCTAssertTrue(try clock.cycle(.alpha, at: last).isClipped)
        XCTAssertEqual(try clock.cycle(.alpha, at: last).name, "Alpha Octadecafracton")
        XCTAssertNoThrow(try clock.date(at: last))
        XCTAssertNoThrow(try clock.pentad(at: last))
        // One microsecond earlier there is a next: the closing instant itself.
        let justBefore = last.advanced(byMicroseconds: -1)
        XCTAssertEqual(try clock.nextThreshold(.helion, after: justBefore).instant, last)
        XCTAssertEqual(try clock.odometer(.helion, at: justBefore).nextChange, last)
        // Position count − 1 is the closing instant; beyond it there is none.
        XCTAssertEqual(clock.instant(atPosition: UInt64(clock.eclipseCount - 1), over: 1), last)
        XCTAssertNil(clock.instant(atPosition: UInt64(clock.eclipseCount), over: 1))
        XCTAssertNil(clock.instant(atPosition: 1, over: 0))
        XCTAssertEqual(try clock.position(at: last).ordinal, clock.eclipseCount - 2)
        // The points of the last Alpha beyond the catalogue are missing.
        let points = try clock.points(.alpha, index: clock.cycleCount(.alpha) - 1)
        XCTAssertNotNil(points.start)
        XCTAssertNil(points.end)
        XCTAssertThrows(.outOfRange, try clock.cycle(.alpha, index: clock.cycleCount(.alpha)))
        XCTAssertThrows(.outOfRange, try clock.sync(number: 1_000_000))
    }

    func testNextInstantsShowTheNewState() throws {
        // "Sleep until next_change, then redraw": the reading at the returned
        // instant is the new state, one microsecond earlier the old one.
        var instant = Vector.a
        var digits = try clock.odometer(.helion, at: instant).digits
        for _ in 0 ..< 20 {
            let odometer = try clock.odometer(.helion, at: instant)
            let next = try XCTUnwrap(odometer.nextChange)
            XCTAssertGreaterThan(next, instant)
            XCTAssertEqual(try clock.odometer(.helion, at: next.advanced(byMicroseconds: -1)).digits, digits)
            let changed = try clock.odometer(.helion, at: next).digits
            XCTAssertNotEqual(changed, digits)
            digits = changed
            instant = next
        }
        // The same for thresholds, and they come in order Peak, Node, Valley, End.
        let threshold = try clock.nextThreshold(.preon, after: Vector.a)
        let at = try XCTUnwrap(threshold.instant)
        let cycleBefore = try clock.cycle(.preon, at: at.advanced(byMicroseconds: -1))
        let cycleAt = try clock.cycle(.preon, at: at)
        XCTAssertEqual(cycleBefore.quarter, threshold.quarter)
        XCTAssertNotEqual(cycleAt.quarter, cycleBefore.quarter)
    }

    func testCyclesTileAndNest() throws {
        let helion = try clock.cycle(.helion, at: Vector.a)
        XCTAssertTrue(helion.start <= Vector.a && Vector.a < helion.end)
        XCTAssertEqual(try clock.cycle(.helion, index: helion.index).start, helion.start)
        XCTAssertEqual(try clock.cycle(.helion, index: helion.index + 1).start, helion.end)

        // The five points: start, three thresholds, end.
        let points = try clock.points(of: helion)
        XCTAssertEqual(points.start, helion.start)
        XCTAssertEqual(points.end, helion.end)
        XCTAssertEqual(points[.end], helion.end)
        let ordered = try [points.start, points.peak, points.node, points.valley, points.end].map { try XCTUnwrap($0) }
        XCTAssertEqual(ordered, ordered.sorted())
        XCTAssertEqual(try clock.nextThreshold(.helion, after: Vector.a).instant, points[.end])

        // Parent and children, by the header's recipes.
        let parent = try XCTUnwrap(clock.parent(of: helion))
        XCTAssertEqual(parent.level.index, 5)
        XCTAssertEqual(parent.index, try clock.cycle(Level(5)!, at: Vector.a).index)
        XCTAssertTrue(parent.start <= helion.start && helion.end <= parent.end)
        XCTAssertNil(try clock.parent(of: clock.cycle(.alpha, at: Vector.a)))

        let children = try clock.children(of: helion)
        XCTAssertEqual(children.count, Level.helion.factor)
        XCTAssertEqual(children.count, 9)
        XCTAssertEqual(children.first?.start, helion.start)
        XCTAssertEqual(children.last?.end, helion.end)
        XCTAssertEqual(children.map(\.local), Array(0 ..< 9))
        for (earlier, later) in zip(children, children.dropFirst()) {
            XCTAssertEqual(earlier.end, later.start)
        }
        XCTAssertEqual(children[7].index, try clock.cycle(Level(7)!, at: Vector.a).index)
        // Further down and up, by the same recipes: the Preons complete in
        // the running Helion are the reading's 29ι.
        let preon = try clock.cycle(.preon, at: Vector.a)
        let firstPreon = try XCTUnwrap(helion.firstDescendantIndex(at: .preon))
        XCTAssertEqual(preon.index - firstPreon, 29)
        XCTAssertEqual(try clock.cycle(.preon, index: firstPreon).start, helion.start)
        XCTAssertEqual(preon.ancestorIndex(at: .helion), helion.index)
        XCTAssertEqual(preon.ancestorIndex(at: .alpha), 5) // α#6
        XCTAssertEqual(helion.firstDescendantIndex(at: .helion), helion.index)
        XCTAssertEqual(helion.firstDescendantIndex(at: Level(7)!), helion.firstChildIndex)
        XCTAssertEqual(helion.ancestorIndex(at: Level(5)!), helion.parentIndex)
        XCTAssertNil(helion.firstDescendantIndex(at: .alpha))
        XCTAssertNil(helion.ancestorIndex(at: .preon))

        // The last Alpha is clipped: it has fewer children than its factor.
        let lastAlpha = try clock.cycle(.alpha, at: clock.last)
        XCTAssertLessThan(try clock.children(of: lastAlpha).count, Level.alpha.factor)
        XCTAssertTrue(try clock.children(of: clock.cycle(.clockMax, at: Vector.a)).isEmpty)
    }

    func testAnotherSeries() throws {
        // The type does not preclude other series: a catalogue from a table
        // of our own (Saros 141's first eclipses, shifted) reads like any other.
        let table = try (0 ..< 30).map { try XCTUnwrap(clock.eclipse($0)).microseconds / 1000 + 86_400_000 }
        let other = try Catalogue(series: 145, eclipseUnixMilliseconds: table)
        XCTAssertEqual(other.series, 145)
        XCTAssertEqual(other.eclipseCount, 30)
        XCTAssertEqual(other.first, Instant(unixMilliseconds: table[0]))
        XCTAssertEqual(other.last, Instant(unixMilliseconds: table[29]))
        XCTAssertEqual(try other.date(at: other.first).stamp, "α#1 β#1 γ#1 δ#1 ε#1 1η 0ι 0λ 0ν")
        XCTAssertEqual(other.anchorOrdinal % 4, 0)
        XCTAssertNotEqual(other, clock)
        XCTAssertEqual(other, other)
        XCTAssertEqual(clock, Catalogue.saros141)
        // The copy keeps its table alive on its own.
        let copy = other
        XCTAssertEqual(try copy.cycle(.helion, at: copy.first).index, 0)

        XCTAssertThrows(.invalidArgument, try Catalogue(series: 1, eclipseUnixMilliseconds: [0]))
        XCTAssertThrows(.invalidArgument, try Catalogue(series: 1, eclipseUnixMilliseconds: [5, 5]))
        XCTAssertThrows(.invalidArgument, try Catalogue(series: 1, eclipseUnixMilliseconds: []))
        XCTAssertThrows(.invalidArgument, try Catalogue(series: 70000, eclipseUnixMilliseconds: [0, 1]))
    }

    func testInstantConversions() {
        XCTAssertEqual(Instant(unixSeconds: 1_791_460_800)?.microseconds, 1_791_460_800_000_000)
        XCTAssertEqual(Instant(unixMilliseconds: 125_593_320_816)?.microseconds, 125_593_320_816_000)
        XCTAssertNil(Instant(unixSeconds: .max))
        XCTAssertNil(Instant(unixMilliseconds: .min))
        let date = Date(timeIntervalSince1970: 1_791_460_800)
        XCTAssertEqual(Instant(date), Vector.a)
        XCTAssertEqual(Vector.a.date, date)
        XCTAssertEqual(Instant(Date(timeIntervalSince1970: 0.5)).microseconds, 500_000)
        XCTAssertLessThan(Vector.b, Vector.a)
        XCTAssertEqual(Vector.a.advanced(byMicroseconds: 5).microseconds(since: Vector.a), 5)
        XCTAssertTrue(clock.contains(.now), "the device clock is inside Saros 141 until 2857")
    }

    func testInstantOfADateIsRoundedAndNeverTraps() {
        // To the nearest microsecond, not cut: 1.6 µs is 2 µs, -1.6 µs is -2 µs.
        XCTAssertEqual(Instant(Date(timeIntervalSince1970: 0.000_001_6)).microseconds, 2)
        XCTAssertEqual(Instant(Date(timeIntervalSince1970: -0.000_001_6)).microseconds, -2)
        // Near the catalogue's opening (1613) a Date's step is about 2 µs, so
        // not every instant survives the trip through Foundation; rounding
        // keeps every one within a microsecond (cutting lost up to two).
        for offset: Int64 in 0 ..< 2_000 {
            let instant = clock.first.advanced(byMicroseconds: offset * 7)
            XCTAssertLessThanOrEqual(abs(Instant(instant.date).microseconds(since: instant)), 1, "\(instant)")
        }
        // In this century the trip is exact.
        for offset: Int64 in 0 ..< 2_000 {
            let instant = Vector.a.advanced(byMicroseconds: offset * 7 + 3)
            XCTAssertEqual(Instant(instant.date), instant)
        }
        // A date beyond what microseconds count is clamped, not a trap.
        XCTAssertEqual(Instant(Date(timeIntervalSince1970: 1e16)).microseconds, .max)
        XCTAssertEqual(Instant(Date(timeIntervalSince1970: -1e16)).microseconds, .min)
    }

    func testErrorsMirrorTheStatusCodes() {
        XCTAssertEqual(FractonicaError.outOfRange.statusCode, -1)
        XCTAssertEqual(FractonicaError.invalidArgument.statusCode, -2)
        XCTAssertEqual(FractonicaError.overflow.statusCode, -3)
        XCTAssertEqual(FractonicaError.bufferTooSmall.statusCode, -4)
        XCTAssertEqual(FractonicaError.unparsable.statusCode, -5)
        XCTAssertEqual(FractonicaError.refused.statusCode, -6)
        XCTAssertEqual(FractonicaError.unknown(-99).statusCode, -99)
    }
}
