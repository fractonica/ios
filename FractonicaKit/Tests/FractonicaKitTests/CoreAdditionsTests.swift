import FractonicaKit
import XCTest

/// The functions the core gained for its clients (the iOS shim's requests
/// among them): one test each, held against the examples fractonica.h gives
/// and against vector A. The expected texts are typed in literally.
final class CoreAdditionsTests: XCTestCase {
    private let g = "\u{202F}" // the core's digit-group space

    // MARK: Pure wording

    func testLightWord() {
        // frc_format_light_word: the one definition of the word light-spans append.
        XCTAssertEqual(Fractonica.lightWord, "light")
        for level in [Level.helion, Level.blink, Level(29)!, Level(62)!] {
            for medium in Medium.allCases {
                XCTAssertEqual(level.lightSpanText(medium),
                               level.lightSpanText(medium, withWord: false) + " " + Fractonica.lightWord)
            }
        }
    }

    func testLevelKindText() {
        // frc_format_level_kind: design ruling 4's words.
        XCTAssertEqual(LevelKind.allCases.map(\.text), ["major", "unit", "between", "sub-Blink"])
        XCTAssertEqual(Level.helion.kind.text, "unit")
        XCTAssertEqual(Level(5)!.kind.text, "between")
        XCTAssertEqual(Level(13)!.kind.text, "sub-Blink")
    }

    func testSignedCount() {
        // frc_format_count_signed
        XCTAssertEqual(Fractonica.count(signed: 4820), "4\(g)820")
        XCTAssertEqual(Fractonica.count(signed: -3), "−3")
        XCTAssertEqual(Fractonica.count(signed: 0), "0")
        XCTAssertEqual(Fractonica.count(signed: .min), "−9\(g)223\(g)372\(g)036\(g)854\(g)775\(g)808")
        XCTAssertEqual(Fractonica.count(signed: .min).utf8.count, 40)
    }

    func testCyclePlace() throws {
        // frc_format_cycle_place: counted from one. At A θ is 8 of 9, the
        // Helion 1 of 11 in its ζ, the Alpha 6 of the catalogue's 18.
        XCTAssertEqual(try clock.cycle(Level(7)!, at: Vector.a).placeText, "8 of 9")
        XCTAssertEqual(try clock.cycle(.helion, at: Vector.a).placeText, "1 of 11")
        XCTAssertEqual(try clock.cycle(.alpha, at: Vector.a).placeText, "6 of 18")
    }

    func testLevelChildren() {
        // frc_format_level_children: counted in levels.
        XCTAssertEqual(Level.helion.childrenText, "9 θ")
        XCTAssertEqual(Level.alpha.childrenText, "5 β")
        XCTAssertEqual(Level(29)!.childrenText, "11 η1")
        XCTAssertNil(Level(62)!.childrenText)
    }

    func testLevelInParent() {
        // frc_format_level_in_parent
        XCTAssertEqual(Level.helion.inParentText, "11 in ζ")
        XCTAssertEqual(Level.beta.inParentText, "5 in α")
        XCTAssertNil(Level.alpha.inParentText)
    }

    func testUnitInParent() {
        // frc_format_unit_in_parent: the parent UNIT, not the parent level.
        XCTAssertEqual(Unit.helion.inParentText, "77 in ε")
        XCTAssertEqual(Unit.blink.inParentText, "25 in λ")
        XCTAssertEqual(Unit.beta.inParentText, "5 in α")
        XCTAssertNil(Unit.alpha.inParentText)
    }

    func testPrefixFactors() {
        // frc_format_prefix_factors: every level in full.
        XCTAssertEqual(Level.helion.prefixFactorsText, "125\(g)125 = 5 · 13 · 5 · 5 · 7 · 11")
        XCTAssertEqual(Level.beta.prefixFactorsText, "5 = 5")
        XCTAssertEqual(Level.alpha.prefixFactorsText, "1")
        XCTAssertEqual(Level(62)!.prefixFactorsText.utf8.count, 428)
    }

    // MARK: Notation

    func testDateTerms() throws {
        // frc_format_date_term: the terms joined by spaces are the stamp.
        let date = try clock.date(at: Vector.a)
        XCTAssertEqual(date.terms, ["α#6", "β#4", "γ#9", "δ#3", "ε#5", "34η", "29ι", "21λ", "3ν"])
        XCTAssertEqual(date.term(.helion), "34η")
        XCTAssertEqual(date.terms.joined(separator: " "), date.stamp)
    }

    func testSignedSpan() throws {
        // frc_format_span_signed: the Helion's thresholds around A.
        let helion = try clock.cycle(.helion, at: Vector.a)
        let points = try clock.points(of: helion)
        XCTAssertEqual(try clock.span(from: Vector.a, to: XCTUnwrap(points.end)).signedText(), "+6ι 43λ")
        XCTAssertEqual(try clock.span(from: Vector.a, to: XCTUnwrap(points.peak)).signedText(), "−20ι 21λ")
        XCTAssertEqual(Span.zero.signedText(), "0ν")
        // A non-zero span below a thousandth of a Blink: no sign, never "0ν".
        let tiny = Span(isNegative: true, blinks: 0, fraction: Fraction(raw: 1))
        XCTAssertEqual(tiny.signedText(), "<0.001ν")
        XCTAssertEqual(tiny.text(), "<0.001ν")
    }

    func testSpanInUnit() throws {
        // frc_format_span_in_unit: cut toward zero. The Sun's drift at A,
        // −48 469.99 s, is 6 235.6 Flavons of 7.773 s: "−6 235λ" (the design
        // prints it rounded, −6 236λ).
        let sync = try clock.sync(at: Vector.a)
        XCTAssertEqual(try clock.span(from: sync.nominal, to: sync.start).text(in: .flavon), "−6\(g)235λ")
        XCTAssertEqual(Span(blinks: 24, fraction: .half).text(in: .flavon), "0λ")
        XCTAssertEqual(Span(isNegative: true, blinks: 24).text(in: .flavon), "0λ")
        XCTAssertEqual(Span(blinks: 58_500).text(in: .helion), "1η")
    }

    func testSpanNextChange() throws {
        // frc_span_next_change: the countdown to the Helion's end at A.
        let end = try XCTUnwrap(clock.cycle(.helion, at: Vector.a).end)
        let next = try XCTUnwrap(clock.spanNextChange(from: Vector.a, to: end))
        XCTAssertGreaterThan(next, Vector.a)
        XCTAssertLessThanOrEqual(next, end)
        let before = next.advanced(byMicroseconds: -1)
        XCTAssertEqual(try clock.span(from: before, to: end).text(), try clock.span(from: Vector.a, to: end).text())
        XCTAssertNotEqual(try clock.span(from: next, to: end).text(), try clock.span(from: Vector.a, to: end).text())
        XCTAssertNil(clock.spanNextChange(from: end, to: end))
        XCTAssertNil(clock.spanNextChange(from: end, to: Vector.a))
    }

    func testSpanNextChangeSince() throws {
        // frc_span_next_change_since: the time elapsed since the Helion's
        // start at A, which grows; and a signed span past its boundary.
        let start = try clock.cycle(.helion, at: Vector.a).start
        let next = try XCTUnwrap(clock.spanNextChange(since: start, at: Vector.a))
        XCTAssertGreaterThan(next, Vector.a)
        let text = try clock.span(from: start, to: Vector.a).text()
        XCTAssertEqual(try clock.span(from: start, to: next.advanced(byMicroseconds: -1)).text(), text)
        XCTAssertNotEqual(try clock.span(from: start, to: next).text(), text)
        // The signed span to the start, read after it, changes at the same instants.
        let signed = try clock.span(from: Vector.a, to: start).signedText()
        XCTAssertEqual(try clock.span(from: next.advanced(byMicroseconds: -1), to: start).signedText(), signed)
        XCTAssertNotEqual(try clock.span(from: next, to: start).signedText(), signed)
        // At the origin "0ν", then "<0.001ν" from the next microsecond.
        XCTAssertEqual(clock.spanNextChange(since: start, at: start), start.advanced(byMicroseconds: 1))
        XCTAssertEqual(try clock.span(from: start, to: start).text(), "0ν")
        XCTAssertEqual(try clock.span(from: start, to: start.advanced(byMicroseconds: 1)).text(), "<0.001ν")
        // Before the origin it is the countdown's function that answers.
        XCTAssertNil(clock.spanNextChange(since: Vector.a, at: start))
        XCTAssertNil(clock.spanNextChange(since: start, at: clock.last))
        // From a few Blinks after an origin, with its decimal, every wake is
        // a change and no change comes between two wakes.
        var now = start.advanced(byMicroseconds: 1)
        var texts: [String] = []
        while let wake = clock.spanNextChange(since: start, at: now), texts.count < 40 {
            let before = try clock.span(from: start, to: wake.advanced(byMicroseconds: -1)).text()
            XCTAssertEqual(before, try clock.span(from: start, to: now).text())
            texts.append(before)
            now = wake
        }
        XCTAssertEqual(texts.first, "<0.001ν")
        XCTAssertEqual(Set(texts).count, texts.count)
    }

    func testPentadNumeral() throws {
        // FRC_PENTAD_NUMERAL: the numeral alone; empty for the Hypopentad.
        XCTAssertEqual(try clock.pentad(at: Vector.a).numeral, "II")
        let parts = try (0 ..< Pentad.perSync).map { try clock.pentad(sync: 4820, index: $0) }
        XCTAssertEqual(parts.map(\.numeral), ["I", "II", "III", ""])
        XCTAssertEqual(parts.map { $0.text(.numeral) }, ["I", "II", "III", ""])
    }

    // MARK: The new struct fields

    func testSyncHelionAndPentadFirst() throws {
        // frc_sync_t.helion and frc_pentad_t.first. At A: Pentad II, its 2nd
        // Helion, the seventh of the sync (place 6).
        let pentad = try clock.pentad(at: Vector.a)
        XCTAssertEqual(pentad.first, 5)
        let sync = try clock.sync(at: Vector.a)
        XCTAssertEqual(sync.helion, 6)
        XCTAssertEqual(sync.helion, pentad.first + pentad.helion - 1)
        XCTAssertEqual(try clock.sync(number: 4820).helion, 0)
        let parts = try (0 ..< Pentad.perSync).map { try clock.pentad(sync: 4820, index: $0) }
        XCTAssertEqual(parts.map(\.first), [0, 5, 10, 15])
        // The place agrees with the Helion count from the sync's start.
        let first = try clock.cycle(Sync.level, at: sync.start).index
        XCTAssertEqual(UInt64(sync.helion), try clock.cycle(Sync.level, at: Vector.a).index - first)
    }

    // MARK: Glyphs and time

    func testGlyphAtQuarter() throws {
        // frc_glyph_at_quarter: Peak 4, Node 8, Valley 12, End 0 at 2 strokes.
        XCTAssertEqual(try Quarter.allCases.map { try Glyph(at: $0).index }, [4, 8, 12, 0])
        XCTAssertEqual(try Glyph(at: .peak).value, 4)
        XCTAssertTrue(try Glyph(at: .node).isDotted)
        XCTAssertEqual(try Glyph(at: .peak, strokes: 3).index, 13)
        XCTAssertThrows(.invalidArgument, try Glyph(at: .peak, strokes: 0))
    }

    func testTimeAtPhase() throws {
        // frc_time_at_phase: phase 0 the start, a quarter the Peak, a half the Node.
        let helion = try clock.cycle(.helion, at: Vector.a)
        let points = try clock.points(of: helion)
        XCTAssertEqual(clock.instant(.helion, index: helion.index, atPhase: .zero), helion.start)
        XCTAssertEqual(clock.instant(.helion, index: helion.index, atPhase: .quarter), points.peak)
        XCTAssertEqual(clock.instant(.helion, index: helion.index, atPhase: .half), points.node)
        // The inverse of the phase: the reading there has reached it, one microsecond earlier not.
        let at = try XCTUnwrap(clock.instant(.helion, index: helion.index, atPhase: helion.phase))
        XCTAssertGreaterThanOrEqual(try clock.cycle(.helion, at: at).phase, helion.phase)
        XCTAssertLessThan(try clock.cycle(.helion, at: at.advanced(byMicroseconds: -1)).phase, helion.phase)
        XCTAssertNil(clock.instant(.helion, index: clock.cycleCount(.helion), atPhase: .zero))
    }

    func testTimeAtSyncPhase() throws {
        // frc_time_at_sync_phase: on the exact start and end of the sync.
        let sync = try clock.sync(at: Vector.a)
        XCTAssertEqual(clock.instant(sync: sync.number, atPhase: .zero), sync.start)
        let at = try XCTUnwrap(clock.instant(sync: sync.number, atPhase: sync.phase))
        XCTAssertLessThanOrEqual(at, Vector.a)
        XCTAssertEqual(try clock.sync(at: at).number, sync.number)
        XCTAssertGreaterThanOrEqual(try clock.sync(at: at).phase, sync.phase)
        XCTAssertLessThan(try clock.sync(at: at.advanced(byMicroseconds: -1)).phase, sync.phase)
        // The Node of the sync is the next quarter boundary after its Peak.
        let peak = try XCTUnwrap(clock.instant(sync: sync.number, atPhase: .quarter))
        XCTAssertEqual(try clock.sync(at: peak).next.instant, clock.instant(sync: sync.number, atPhase: .half))
        XCTAssertNil(clock.instant(sync: 1_000_000, atPhase: .zero))
    }

    // MARK: Ladder

    func testBandEdges() throws {
        // frc_band_edges: SPEC §16.2, written with two digits.
        let visible = try XCTUnwrap(Band.visible.edges)
        XCTAssertEqual(visible.low.text(.frequency, digits: 2), "400 THz")
        XCTAssertEqual(visible.high.text(.frequency, digits: 2), "790 THz")
        let audible = try XCTUnwrap(Band.audible.edges)
        XCTAssertEqual(audible.low.mantissa, 20_000_000_000_000_000)
        XCTAssertEqual(audible.low.exponent, -15)
        XCTAssertEqual(try XCTUnwrap(Band.gamma.edges).high.text(.frequency, digits: 2), "3.4 × 10²⁹ Hz")
        XCTAssertNil(Band.noBand.edges)
        // The bands join: each starts where the one before it ends.
        let bands = Band.allCases.filter { $0 != .noBand }
        for (lower, upper) in zip(bands, bands.dropFirst()) {
            XCTAssertEqual(try XCTUnwrap(lower.edges).high, try XCTUnwrap(upper.edges).low, "\(lower)")
        }
    }

    // MARK: Earth

    func testCivilText() throws {
        // frc_format_civil_text, at vector A in UTC.
        let a = CivilTime(Vector.a)
        let expected: [CivilForm: String] = [
            .dateTime: "THU 8 OCT 2026 · 12:00:00", .date: "THU 8 OCT 2026", .time: "12:00:00",
            .minute: "12:00", .dayMonth: "8 OCT", .dayMonthTime: "8 OCT 12:00", .monthYear: "OCT 2026",
            .offset: "UTC", .dayMonthYear: "8 OCT 2026", .dayMonthSeconds: "8 OCT 12:00:00",
            .isoDate: "2026-10-08", .weekday: "THU", .month: "OCT", .year: "2026",
        ]
        for form in CivilForm.allCases {
            XCTAssertEqual(a.text(form), expected[form], "\(form)")
        }
        // Another day an hour and a half later, at UTC+3.
        let later = CivilTime(Vector.a.advanced(byMicroseconds: 49_000_000_000), utcOffsetSeconds: 10_800)
        XCTAssertEqual(later.text(.dayMonthSeconds), "9 OCT 04:36:40")
        XCTAssertEqual(later.text(.offset), "UTC+3")
        XCTAssertEqual(CivilTime.offsetText(seconds: -9000), "UTC−2:30")
        XCTAssertEqual(CivilTime.offsetText(seconds: 0), "UTC")
        // Under a day either way; a day or more is refused (it was "UTC+24").
        XCTAssertEqual(CivilTime.offsetText(seconds: 86_399), "UTC+23:59")
        XCTAssertEqual(CivilTime.offsetText(seconds: -86_399), "UTC−23:59")
        XCTAssertNil(CivilTime.offsetText(seconds: 86_400))
        XCTAssertNil(CivilTime.offsetText(seconds: -86_400))
        XCTAssertNil(CivilTime.offsetText(seconds: Int(Int32.min)))
        // A year before 1 with U+2212 in every form but the ISO date.
        let ides = CivilTime(year: -44, month: 3, day: 15, hour: 9, minute: 5, second: 7)
        XCTAssertEqual(ides.text(.year), "−0044")
        XCTAssertEqual(ides.text(.dayMonthYear), "15 MAR −0044")
        XCTAssertEqual(ides.text(.dateTime), "THU 15 MAR −0044 · 09:05:07")
        XCTAssertEqual(ides.text(.isoDate), "-0044-03-15")
        XCTAssertNil(CivilTime(year: 2026, month: 2, day: 31).text(.date))
    }

    func testDuration() {
        // frc_format_duration: rounded once, then worded.
        XCTAssertEqual(Fractonica.duration(microseconds: 1_433_000_000), "23 min 53 s")
        XCTAssertEqual(Fractonica.duration(microseconds: 3_720_000_000), "1 h 2 min")
        XCTAssertEqual(Fractonica.duration(microseconds: 273_600_000_000), "3 d 4 h")
        XCTAssertEqual(Fractonica.duration(microseconds: 400_000), "0.4 s")
        XCTAssertEqual(Fractonica.duration(microseconds: 9_271_000), "9.27 s")
        XCTAssertEqual(Fractonica.duration(microseconds: 9_995_000), "10 s")
        XCTAssertEqual(Fractonica.duration(microseconds: 59_600_000), "1 min")
        XCTAssertEqual(Fractonica.duration(microseconds: 3_760_000_000, maxParts: 3), "1 h 2 min 40 s")
        XCTAssertEqual(Fractonica.duration(microseconds: -400_000), "−0.4 s")
    }

    func testCivilValidate() {
        // frc_civil_validate
        XCTAssertTrue(CivilTime(year: 2024, month: 2, day: 29).isValid)
        XCTAssertFalse(CivilTime(year: 2026, month: 2, day: 29).isValid)
        XCTAssertFalse(CivilTime(year: 2026, month: 2, day: 31).isValid)
        XCTAssertFalse(CivilTime(year: 1900, month: 2, day: 29).isValid)
        XCTAssertFalse(CivilTime(year: 2026, month: 10, day: 8, hour: 24).isValid)
        XCTAssertFalse(CivilTime(year: 2026, month: 10, day: -1).isValid)
        XCTAssertTrue(CivilTime(Vector.a).isValid)
    }

    func testParseCivil() throws {
        // frc_parse_civil
        let zoned = try CivilTime.parse("2026-10-08T14:00:00+02:00")
        XCTAssertTrue(zoned.namesOffset)
        XCTAssertEqual(zoned.time.utcOffsetSeconds, 7200)
        XCTAssertEqual(zoned.time.hour, 14)
        XCTAssertEqual(zoned.time.instant, Vector.a)
        let wall = try CivilTime.parse("8 OCT 2026 12:00")
        XCTAssertFalse(wall.namesOffset)
        XCTAssertEqual(wall.time.weekday, 3) // Thursday
        XCTAssertEqual(wall.time.instant(in: TimeZone(identifier: "UTC")!), Vector.a)
        XCTAssertEqual(try CivilTime.parse("THU 8 OCT 2026 · 12:00:00").time.instant, Vector.a)
        XCTAssertEqual(try CivilTime.parse("2026-10-08T12:00:00.000Z").time.instant, Vector.a)
        XCTAssertThrows(.outOfRange, try CivilTime.parse("31 FEB 2026"))
        XCTAssertThrows(.outOfRange, try CivilTime.parse("2026-10-08 24:00"))
        XCTAssertThrows(.unparsable, try CivilTime.parse("8 OCT 2026 12:00 CEST"))
        XCTAssertThrows(.unparsable, try CivilTime.parse("FRI 8 OCT 2026"))
        // Spaces only: no tab, newline or carriage return between the parts.
        XCTAssertThrows(.unparsable, try CivilTime.parse("8\tOCT 2026"))
        XCTAssertThrows(.unparsable, try CivilTime.parse("8 OCT 2026\n12:00"))
        XCTAssertThrows(.unparsable, try CivilTime.parse("8 OCT\r2026"))
        // A separator after the weekday; 'T' only after an ISO date.
        XCTAssertThrows(.unparsable, try CivilTime.parse("THU8 OCT 2026"))
        XCTAssertThrows(.unparsable, try CivilTime.parse("8 OCT 2026T12:00"))
        // Spaces on either side of the weekday's comma.
        let utc = TimeZone(identifier: "UTC")!
        let dayStart = Instant(unixSeconds: 1_791_417_600)! // 2026-10-08 00:00 UTC
        XCTAssertEqual(try CivilTime.parse("THU , 8 OCT 2026").time.instant(in: utc), dayStart)
        XCTAssertEqual(try CivilTime.parse("thu ,8 oct 2026").time.instant(in: utc), dayStart)
        // Shape first, then range, then weekday.
        XCTAssertThrows(.outOfRange, try CivilTime.parse("FRI 8 OCT 2026 24:00"))
        XCTAssertThrows(.unparsable, try CivilTime.parse("SAT 29 FEB 2024"))
    }
}
