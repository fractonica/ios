import FractonicaKit
import XCTest

/// SPEC.md §12, typed in literally: vectors A, B, C and the anchor, read
/// through the kit. If one of these fails the kit passes the wrong argument
/// somewhere (the core itself holds the same numbers in its own tests).
final class SpecClockVectorTests: XCTestCase {
    // MARK: A: 2026-10-08T12:00:00Z

    func testVectorA_depth7() throws {
        let level = try XCTUnwrap(Level(6))
        XCTAssertEqual(level, .helion)

        // index / value / derivative: 13 / −3 / +1
        let glyph = try clock.glyph(level, at: Vector.a, strokes: 2)
        XCTAssertEqual(glyph.index, 13)
        XCTAssertEqual(glyph.value, -3)
        XCTAssertEqual(glyph.derivative, 1)
        XCTAssertFalse(glyph.isDotted)

        // odometer digits (2 × 2-stroke): [13, 0]
        let odometer = try clock.odometer(level, at: Vector.a, strokes: 2, digits: 2)
        XCTAssertEqual(odometer.digits, [13, 0])
        XCTAssertEqual(odometer.strokes, 2)
        XCTAssertEqual(odometer.stateCount, 16)
        XCTAssertEqual(odometer.glyphs.map(\.index), [13, 0])

        // cycle / local / siblings: 717211 / 0 / 11
        let cycle = try clock.cycle(level, at: Vector.a)
        XCTAssertEqual(cycle.index, 717_211)
        XCTAssertEqual(cycle.local, 0)
        XCTAssertEqual(cycle.siblings, 11)
        XCTAssertEqual(cycle.level, level)

        // next threshold: end at 1791464172.428
        let next = try clock.nextThreshold(level, after: Vector.a)
        XCTAssertEqual(next.quarter, .end)
        XCTAssertInstant(next.instant, unixMilliseconds: 1_791_464_172_428)
        XCTAssertEqual(next.instant.flatMap(isoUTC), "2026-10-08T12:56:12.428Z")
        XCTAssertEqual(cycle.quarter, .end)

        // 3-stroke index / value: 42 / −10
        let three = try clock.glyph(level, at: Vector.a, strokes: 3)
        XCTAssertEqual(three.index, 42)
        XCTAssertEqual(three.value, -10)
    }

    func testVectorA_depth8() throws {
        let level = try XCTUnwrap(Level(7))

        // index / value / derivative: 5 / 3 / −1 (dotted)
        let glyph = try clock.glyph(level, at: Vector.a)
        XCTAssertEqual(glyph.index, 5)
        XCTAssertEqual(glyph.value, 3)
        XCTAssertEqual(glyph.derivative, -1)
        XCTAssertTrue(glyph.isDotted)

        XCTAssertEqual(try clock.odometer(level, at: Vector.a).digits, [5, 4])

        // cycle / local / siblings: 6454906 / 7 / 9
        let cycle = try clock.cycle(level, at: Vector.a)
        XCTAssertEqual(cycle.index, 6_454_906)
        XCTAssertEqual(cycle.local, 7)
        XCTAssertEqual(cycle.siblings, 9)

        // next threshold: node at 1791461140.937
        let next = try clock.nextThreshold(level, after: Vector.a)
        XCTAssertEqual(next.quarter, .node)
        XCTAssertInstant(next.instant, unixMilliseconds: 1_791_461_140_937)
    }

    func testVectorA_solarSync() throws {
        let sync = try clock.sync(at: Vector.a)
        XCTAssertEqual(sync.number, 4820)
        XCTAssertInstant(sync.start, unixMilliseconds: 1_791_336_849_826)
        XCTAssertEqual(isoUTC(sync.start), "2026-10-07T01:34:09.826Z")
        XCTAssertEqual(isoUTC(sync.end), "2026-10-11T01:33:59.745Z")
        XCTAssertEqual(sync.phase.value, 0.358662585, accuracy: 1e-9)
        // drift −48469.9899 s
        XCTAssertEqual(Double(sync.driftMicroseconds) / 1_000_000, -48469.9899, accuracy: 0.00006)
        XCTAssertEqual(sync.start.microseconds(since: sync.nominal), sync.driftMicroseconds)

        // digits (3 × 2-stroke): [5, 11, 13]; (2 × 3-stroke): [18, 33]
        XCTAssertEqual(try clock.syncOdometer(at: Vector.a).digits, [5, 11, 13])
        XCTAssertEqual(try clock.syncOdometer(at: Vector.a, strokes: 3, digits: 2).digits, [18, 33])

        // next threshold: node at 1791509644.786
        XCTAssertEqual(sync.next.quarter, .node)
        XCTAssertInstant(sync.next.instant, unixMilliseconds: 1_791_509_644_786)
        XCTAssertEqual(sync.next.instant.flatMap(isoUTC), "2026-10-09T01:34:04.786Z")
        XCTAssertEqual(sync.quarter, .node)

        // The same sync asked for by number has no running phase or next.
        let byNumber = try clock.sync(number: 4820)
        XCTAssertEqual(byNumber.start, sync.start)
        XCTAssertEqual(byNumber.end, sync.end)
        XCTAssertEqual(byNumber.phase, .zero)
        XCTAssertNil(byNumber.next.instant)
    }

    // MARK: B: 2000-01-01T00:00:00Z

    func testVectorB() throws {
        // depth 7: index 5 (3, dotted); digits [5, 6]; local 9 of 11; next node at 946687783.046
        let glyph7 = try clock.glyph(.helion, at: Vector.b)
        XCTAssertEqual(glyph7.index, 5)
        XCTAssertEqual(glyph7.value, 3)
        XCTAssertTrue(glyph7.isDotted)
        XCTAssertEqual(try clock.odometer(.helion, at: Vector.b).digits, [5, 6])
        let cycle7 = try clock.cycle(.helion, at: Vector.b)
        XCTAssertEqual(cycle7.local, 9)
        XCTAssertEqual(cycle7.siblings, 11)
        let next7 = try clock.nextThreshold(.helion, after: Vector.b)
        XCTAssertEqual(next7.quarter, .node)
        XCTAssertInstant(next7.instant, unixMilliseconds: 946_687_783_046)

        // depth 8: index 0; digits [0, 6]; local 3 of 9; next peak at 946685256.803
        let level8 = try XCTUnwrap(Level(7))
        XCTAssertEqual(try clock.glyph(level8, at: Vector.b).index, 0)
        XCTAssertEqual(try clock.odometer(level8, at: Vector.b).digits, [0, 6])
        let cycle8 = try clock.cycle(level8, at: Vector.b)
        XCTAssertEqual(cycle8.local, 3)
        XCTAssertEqual(cycle8.siblings, 9)
        let next8 = try clock.nextThreshold(level8, after: Vector.b)
        XCTAssertEqual(next8.quarter, .peak)
        XCTAssertInstant(next8.instant, unixMilliseconds: 946_685_256_803)

        // solar: sync 2375; start 946369476.520; phase 0.912420883; drift −23843.2957 s;
        // digits [14, 9, 9]; next end at 946715066.462
        let sync = try clock.sync(at: Vector.b)
        XCTAssertEqual(sync.number, 2375)
        XCTAssertInstant(sync.start, unixMilliseconds: 946_369_476_520)
        XCTAssertEqual(isoUTC(sync.start), "1999-12-28T08:24:36.520Z")
        XCTAssertEqual(sync.phase.value, 0.912420883, accuracy: 1e-9)
        XCTAssertEqual(Double(sync.driftMicroseconds) / 1_000_000, -23843.2957, accuracy: 0.00006)
        XCTAssertEqual(try clock.syncOdometer(at: Vector.b).digits, [14, 9, 9])
        XCTAssertEqual(sync.next.quarter, .end)
        XCTAssertInstant(sync.next.instant, unixMilliseconds: 946_715_066_462)
    }

    // MARK: C: 2061-06-15T18:30:00Z

    func testVectorC() throws {
        // depth 7: index 10 (−2, dotted); digits [10, 3]; local 0 of 11; next valley at 2886087806.395
        let glyph7 = try clock.glyph(.helion, at: Vector.c)
        XCTAssertEqual(glyph7.index, 10)
        XCTAssertEqual(glyph7.value, -2)
        XCTAssertTrue(glyph7.isDotted)
        XCTAssertEqual(try clock.odometer(.helion, at: Vector.c).digits, [10, 3])
        let cycle7 = try clock.cycle(.helion, at: Vector.c)
        XCTAssertEqual(cycle7.local, 0)
        XCTAssertEqual(cycle7.siblings, 11)
        let next7 = try clock.nextThreshold(.helion, after: Vector.c)
        XCTAssertEqual(next7.quarter, .valley)
        XCTAssertInstant(next7.instant, unixMilliseconds: 2_886_087_806_395)

        // depth 8: index 12 (−4, valley); digits [12, 1]; local 5 of 9; next end at 2886086290.651
        let level8 = try XCTUnwrap(Level(7))
        let glyph8 = try clock.glyph(level8, at: Vector.c)
        XCTAssertEqual(glyph8.index, 12)
        XCTAssertEqual(glyph8.value, -4)
        XCTAssertEqual(glyph8.derivative, 0)
        XCTAssertEqual(try clock.odometer(level8, at: Vector.c).digits, [12, 1])
        let cycle8 = try clock.cycle(level8, at: Vector.c)
        XCTAssertEqual(cycle8.local, 5)
        XCTAssertEqual(cycle8.siblings, 9)
        let next8 = try clock.nextThreshold(level8, after: Vector.c)
        XCTAssertEqual(next8.quarter, .end)
        XCTAssertInstant(next8.instant, unixMilliseconds: 2_886_086_290_651)

        // solar: sync 7987; start 2061-06-12T16:31:59.691Z; phase 0.770510076;
        // drift −81000.1249 s; digits [12, 5, 4]; next end at 2886165109.343
        let sync = try clock.sync(at: Vector.c)
        XCTAssertEqual(sync.number, 7987)
        XCTAssertEqual(isoUTC(sync.start), "2061-06-12T16:31:59.691Z")
        XCTAssertEqual(sync.phase.value, 0.770510076, accuracy: 1e-9)
        XCTAssertEqual(Double(sync.driftMicroseconds) / 1_000_000, -81000.1249, accuracy: 0.00006)
        XCTAssertEqual(try clock.syncOdometer(at: Vector.c).digits, [12, 5, 4])
        XCTAssertEqual(sync.next.quarter, .end)
        XCTAssertInstant(sync.next.instant, unixMilliseconds: 2_886_165_109_343)
    }

    // MARK: Anchor

    func testAnchorPlusOneSecond() throws {
        // "Unix 125593320.816 (one second after the anchor eclipse) gives
        //  sync 0, drift 0 and digits [0, 0, 0]."
        let sync = try clock.sync(at: Vector.anchorPlusOneSecond)
        XCTAssertEqual(sync.number, 0)
        XCTAssertEqual(sync.driftMicroseconds, 0)
        XCTAssertEqual(try clock.syncOdometer(at: Vector.anchorPlusOneSecond).digits, [0, 0, 0])

        XCTAssertEqual(clock.anchorOrdinal, 20)
        let anchor = try XCTUnwrap(clock.eclipse(clock.anchorOrdinal))
        XCTAssertEqual(Vector.anchorPlusOneSecond.microseconds(since: anchor), 1_000_000)
        XCTAssertEqual(sync.start, anchor)
        XCTAssertEqual(sync.nominal, anchor)
    }

    // MARK: Pentads (SPEC §7.5; DESIGN.md: "Pentad II Helion 2" at A)

    func testPentadAtA() throws {
        let pentad = try clock.pentad(at: Vector.a)
        XCTAssertEqual(pentad.sync, 4820)
        XCTAssertEqual(pentad.index, 1)
        XCTAssertEqual(pentad.helion, 2)
        XCTAssertEqual(pentad.helions, 5)
        XCTAssertFalse(pentad.isHypopentad)
        XCTAssertEqual(pentad.name, "Pentad II")
        XCTAssertEqual(pentad.mark, "⬠II")
        XCTAssertEqual(pentad.text(.full, withHelion: true), "Pentad II, 2nd Helion")
        XCTAssertEqual(pentad.text(.short, withHelion: true), "⬠II·2")
        XCTAssertEqual(pentad.text(.ascii, withHelion: true), "P2.2")
        XCTAssertTrue(pentad.start <= Vector.a && Vector.a < pentad.end)

        // The four Pentads of the sync tile it; the last is the Hypopentad.
        let sync = try clock.sync(number: 4820)
        let parts = try (0 ..< Pentad.perSync).map { try clock.pentad(sync: 4820, index: $0) }
        XCTAssertEqual(parts.map(\.name), ["Pentad I", "Pentad II", "Pentad III", "Hypopentad"])
        XCTAssertEqual(parts.map(\.helions), [5, 5, 5, 4])
        XCTAssertEqual(parts.map(\.helions).reduce(0, +), Sync.helions)
        XCTAssertEqual(parts.map(\.isHypopentad), [false, false, false, true])
        XCTAssertEqual(parts.first?.start, sync.start)
        XCTAssertEqual(parts.last?.end, sync.end)
        for (earlier, later) in zip(parts, parts.dropFirst()) {
            XCTAssertEqual(earlier.end, later.start)
        }
        XCTAssertEqual(parts[3].mark, "◻")
        XCTAssertEqual(parts[3].text(.ascii), "H")
        // A Pentad asked for by number has no running Helion to name.
        XCTAssertEqual(parts[1].helion, 0)
        XCTAssertNil(parts[1].text(.full, withHelion: true))
        XCTAssertThrows(.invalidArgument, try clock.pentad(sync: 4820, index: 4))
    }

    // MARK: The constants the vectors are given under

    func testReferenceConfiguration() {
        XCTAssertEqual(clock.series, 141)
        XCTAssertEqual(clock.eclipseCount, 70)
        XCTAssertEqual(Sync.level, .helion)
        XCTAssertEqual(Sync.helions, 19)
        XCTAssertEqual(Sync.nominalDays, 4)
        XCTAssertEqual(Fractonica.specVersion, "2.2.0")
        XCTAssertFalse(Fractonica.coreVersion.isEmpty)
    }
}
