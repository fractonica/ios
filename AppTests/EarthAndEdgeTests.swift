import XCTest
import FractonicaKit
@testable import Fractonica

/// Earth mode's texts and their timing, and the catalogue's edges: the
/// places where the app once showed a stale second, a time of day without
/// its day, a label with no value, or a day tick in the wrong place.
final class EarthAndEdgeTests: XCTestCase {
    private let clock = Catalogue.saros141
    private let a = Instant(unixSeconds: 1_791_460_800)!
    private let utc = TimeZone(identifier: "UTC")!

    // MARK: Timing (hard rule 5)

    /// In Earth mode every change of an Earth text on screen is a wake of the
    /// scheduler: from any instant, the text just before the next wake is
    /// the text now. (Before, a second could be shown up to 0.3 s late.)
    func testEveryEarthSecondIsAWake() throws {
        for focus in [Level.delta, .helion, Level(8)!] {
            var now = a.advanced(byMicroseconds: 123_457)
            var wakes = 0
            while now < a.advanced(byMicroseconds: 30_000_000) {
                let next = try XCTUnwrap(ClockSchedule.nextChange(in: clock, after: now, focus: focus, nestDepth: 2,
                                                                  earth: true))
                let justBefore = next.advanced(byMicroseconds: -1)
                XCTAssertEqual(EarthText.dateLine(justBefore, zone: utc), EarthText.dateLine(now, zone: utc),
                               "focus \(focus.index): a second turned before the wake at \(next)")
                now = next
                wakes += 1
            }
            XCTAssertGreaterThanOrEqual(wakes, 30)
        }
        // Pure mode is not woken for Earth seconds.
        let pure = try XCTUnwrap(ClockSchedule.nextChange(in: clock, after: a.advanced(byMicroseconds: 1), focus: .delta,
                                                          nestDepth: 2))
        let earth = try XCTUnwrap(ClockSchedule.nextChange(in: clock, after: a.advanced(byMicroseconds: 1), focus: .delta,
                                                           nestDepth: 2, earth: true))
        XCTAssertLessThanOrEqual(earth, pure)
        XCTAssertEqual(EarthText.nextEarthSecond(after: a), a.advanced(byMicroseconds: 1_000_000))
        XCTAssertEqual(EarthText.nextEarthSecond(after: Instant(microseconds: -1)), Instant(microseconds: 0))
    }

    /// A countdown's text is never stale either: from a few seconds before
    /// the Helion's End at A (where the countdown keeps a decimal and turns
    /// every tenth of a Blink), the text just before each wake is the text
    /// at the last one (`frc_span_next_change` among the scheduler's
    /// candidates; the Blink's end alone was up to a Blink late).
    func testEveryCountdownChangeIsAWake() throws {
        let end = try XCTUnwrap(clock.cycle(.helion, at: a).end)
        var now = end.advanced(byMicroseconds: -2_000_000)
        var texts: Set<String> = []
        while now < end {
            let next = try XCTUnwrap(ClockSchedule.nextChange(in: clock, after: now, focus: .helion, nestDepth: 2))
            let text = try clock.span(from: now, to: end).text()
            XCTAssertEqual(try clock.span(from: next.advanced(byMicroseconds: -1), to: end).text(), text,
                           "the countdown changed before the wake at \(next)")
            texts.insert(text)
            now = next
        }
        XCTAssertGreaterThanOrEqual(texts.count, 60) // 6.4ν, 6.3ν … 0.1ν, then <0.001ν and the like
    }

    /// A signed span past its zero is never stale: the lens lists the
    /// Helion's Peak at A as an elapsed span (`−…`), which from the Peak on
    /// grows; the scheduler wakes for each of its changes
    /// (`frc_span_next_change_since`).
    func testEveryElapsedChangeIsAWake() throws {
        let peak = try XCTUnwrap(clock.points(of: clock.cycle(.helion, at: a)).peak)
        var now = peak
        let stop = peak.advanced(byMicroseconds: 2_000_000)
        var texts: Set<String> = []
        while now < stop {
            let next = try XCTUnwrap(ClockSchedule.nextChange(in: clock, after: now, focus: .helion, nestDepth: 2))
            let text = try clock.span(from: now, to: peak).signedText()
            XCTAssertEqual(try clock.span(from: next.advanced(byMicroseconds: -1), to: peak).signedText(), text,
                           "the elapsed span changed before the wake at \(next)")
            texts.insert(text)
            now = next
        }
        XCTAssertGreaterThanOrEqual(texts.count, 30) // 0ν, <0.001ν, 0.001ν … −6.4ν
    }

    /// The NOW mark's offset (the cursor from now) is never stale, on
    /// either side of the cursor: shrinking towards it, growing past it.
    func testTheCursorOffsetChangeIsAWake() throws {
        let cursor = try XCTUnwrap(clock.points(of: clock.cycle(.helion, at: a)).peak)
        var now = cursor.advanced(byMicroseconds: -1_500_000)
        let stop = cursor.advanced(byMicroseconds: 1_500_000)
        var texts: Set<String> = []
        while now < stop {
            let next = try XCTUnwrap(ClockSchedule.nextChange(in: clock, after: now, focus: .alpha, nestDepth: 2,
                                                              cursor: cursor))
            let text = try clock.span(from: now, to: cursor).signedText()
            XCTAssertEqual(try clock.span(from: next.advanced(byMicroseconds: -1), to: cursor).signedText(), text,
                           "the NOW mark changed before the wake at \(next)")
            texts.insert(text)
            now = next
        }
        XCTAssertGreaterThanOrEqual(texts.count, 40)
    }

    // MARK: The texts

    func testDurationsAreRoundedBeforeTheirWordingIsChosen() {
        func duration(_ microseconds: Int64, from start: Instant? = nil) -> String {
            let start = start ?? a
            return EarthText.duration(from: start, to: start.advanced(byMicroseconds: microseconds))
        }
        XCTAssertEqual(duration(9_996_000), "10 s")
        XCTAssertEqual(duration(9_994_000), "9.99 s")
        // The core's wording drops a zero part (was the shim's "1 min 0 s").
        XCTAssertEqual(duration(59_600_000), "1 min")
        XCTAssertEqual(duration(59_400_000), "59 s")
        XCTAssertEqual(duration(3_372_000_000), "56 min 12 s")
        for microseconds in stride(from: Int64(59_000_000), through: 60_999_999, by: 37_000) {
            XCTAssertNotEqual(duration(microseconds), "60 s")
        }
    }

    /// The clock of the moment shown is never ahead of it: 23:59:59.6 is
    /// still the day before (the date line, the Earth tumblers). A
    /// threshold, an instant the core computed, is said to its nearest
    /// second.
    func testTheMomentIsCutToTheSecondAndAThresholdRounded() {
        let late = Instant(unixSeconds: 1_791_503_999)!.advanced(byMicroseconds: 600_000) // 2026-10-08 23:59:59.6
        XCTAssertEqual(EarthText.dateLine(late, zone: utc), "THU 8 OCT 2026 · 23:59:59 UTC")
        XCTAssertEqual(EarthText.earthFields(late, zone: utc).second, "59")
        XCTAssertEqual(EarthText.earthFields(late, zone: utc).weekday, "THU")
        XCTAssertEqual(EarthText.clock(late, zone: utc, seconds: true), "00:00:00")
    }

    func testImpossibleEarthDatesAreRefused() throws {
        XCTAssertNil(EarthText.instant(parsing: "2026-02-31", zone: utc))
        XCTAssertNil(EarthText.instant(parsing: "31 FEB 2026", zone: utc))
        XCTAssertNil(EarthText.instant(parsing: "2025-02-29", zone: utc))
        XCTAssertEqual(EarthText.instant(parsing: "2028-02-29", zone: utc), Instant(unixSeconds: 1_835_395_200))
        XCTAssertEqual(EarthText.instant(parsing: "8 OCT 2026 12:00:00", zone: utc), a)
        // The core's parser also reads the date line as the app writes it, and a zone.
        XCTAssertEqual(EarthText.instant(parsing: "THU 8 OCT 2026 · 12:00:00", zone: utc), a)
        let paris = try XCTUnwrap(TimeZone(identifier: "Europe/Paris"))
        XCTAssertEqual(EarthText.instant(parsing: "2026-10-08 14:00", zone: paris), a)
        XCTAssertEqual(EarthText.instant(parsing: "2026-10-08T12:00:00Z", zone: paris), a)
    }

    /// A time of day alone only for a threshold on the day shown; a day and
    /// a time within the year; a date beyond. The same on the bezel and
    /// under the NOW countdowns.
    func testFarThresholdsCarryTheirDay() throws {
        let alpha = NowReading.read(clock, at: a, focus: .alpha)
        let earth = NowEarth.read(alpha, at: a, zone: utc)
        let alphaThreshold = try XCTUnwrap(alpha.live?.countdowns.first?.threshold.instant)
        XCTAssertGreaterThan(alphaThreshold.microseconds(since: a), 300 * 86_400_000_000)
        XCTAssertFalse(try XCTUnwrap(earth.countdownTimes.first).contains(":"), "a bare clock time for a far threshold")
        let layer = EarthLayer.read(InstrumentReading.read(clock, at: a, focus: .alpha), clock: clock, at: a, zone: utc)
        for (quarter, text) in layer.bezelTimes {
            XCTAssertFalse(text.contains(":"), "\(quarter): \(text)")
        }
        XCTAssertEqual(layer.bezelTimes[.valley], "JAN 2028")
        // At δ the thresholds are weeks away: their day.
        let delta = EarthLayer.read(InstrumentReading.read(clock, at: a, focus: .delta), clock: clock, at: a, zone: utc)
        XCTAssertEqual(delta.bezelTimes[.end], "17 OCT")
        // The Helion's End is the same day: the design's `END 12:56`.
        let helion = EarthLayer.read(InstrumentReading.read(clock, at: a, focus: .helion), clock: clock, at: a, zone: utc)
        XCTAssertEqual(helion.bezelTimes[.end], "12:56")
    }

    // MARK: Civil days on the Sun's ring

    /// Whole hours and the first instant of each day come from the zone's
    /// own calendar: a half-hour change (Lord Howe, 4 October 2026) and a
    /// change at midnight (Cairo, 24 April 2026, no 00:00 that day).
    func testCivilHoursAcrossOddDaylightSavingChanges() throws {
        let lordHowe = try XCTUnwrap(TimeZone(identifier: "Australia/Lord_Howe"))
        let hours = ShimCoreGaps.civilHours(from: Instant(unixSeconds: 1_791_000_000)!,
                                            to: Instant(unixSeconds: 1_791_000_000 + 4 * 86_400)!, zone: lordHowe)
        XCTAssertFalse(hours.isEmpty)
        for hour in hours {
            let civil = CivilTime(hour.instant, timeZone: lordHowe)
            XCTAssertEqual(civil.minute, 0, "\(hour.instant)")
            XCTAssertEqual(civil.hour, hour.hour)
            XCTAssertEqual(hour.startsDay, civil.hour == 0)
        }
        XCTAssertEqual(hours.filter(\.startsDay).count, 4)

        let cairo = try XCTUnwrap(TimeZone(identifier: "Africa/Cairo"))
        // 22 April 2026 00:00 UTC, five days.
        let days = ShimCoreGaps.civilHours(from: Instant(unixSeconds: 1_776_816_000)!,
                                           to: Instant(unixSeconds: 1_776_816_000 + 5 * 86_400)!, zone: cairo)
            .filter(\.startsDay)
            .map { CivilTime($0.instant, timeZone: cairo) }
        XCTAssertEqual(days.map(\.day), [23, 24, 25, 26, 27])
        XCTAssertEqual(days.map(\.hour), [0, 1, 0, 0, 0], "the 24th starts at 01:00")
    }

    /// The day ticks stand where the core puts their instants among the
    /// sync's Helions, in order, and the design's four days hang at A.
    func testDayTicksArePlacedByTheCore() throws {
        let reading = InstrumentReading.read(clock, at: a, focus: .helion)
        let layer = EarthLayer.read(reading, clock: clock, at: a, zone: utc)
        XCTAssertEqual(layer.sunTicks.compactMap(\.label), ["8", "9", "10", "11"])
        let fractions = layer.sunTicks.map(\.fraction)
        XCTAssertEqual(fractions, fractions.sorted())
        XCTAssertTrue(fractions.allSatisfy { (0 ... 1).contains($0) })
        let sun = try XCTUnwrap(reading.live?.sun)
        let midnight = Instant(unixSeconds: 1_791_417_600)! // 8 Oct 00:00 UTC
        // The core's place of that midnight: the running Helion's place in
        // the sync (frc_sync_t.helion) and how far through it the instant is.
        let place = Double(try clock.sync(at: midnight).helion) + (try clock.cycle(Sync.level, at: midnight)).phase.value
        let tick = try XCTUnwrap(layer.sunTicks.first { $0.label == "8" })
        XCTAssertEqual(tick.fraction, place / Double(Sync.helions), accuracy: 1e-6)
    }

    // MARK: The catalogue's edges

    /// At the closing instant nothing comes later: no countdown, no row of
    /// "next thresholds", no Sun quarter is listed without a value.
    func testTheClosingInstantListsNothingThatDoesNotExist() throws {
        let last = clock.last
        for focus in [Level.helion, .alpha, Level(12)!] {
            let now = NowReading.read(clock, at: last, focus: focus)
            let live = try XCTUnwrap(now.live, "the closing instant is inside the catalogue")
            XCTAssertTrue(live.countdowns.allSatisfy { $0.threshold.instant != nil && !$0.span.isEmpty })
            XCTAssertTrue(live.upcoming.allSatisfy { $0.threshold.instant != nil && !$0.span.isEmpty })
            let wave = WaveReading.read(clock, at: last, focus: focus, reach: 2, depth: 2)
            XCTAssertTrue((wave.live?.upcoming ?? []).allSatisfy { $0.threshold.instant != nil && !$0.span.isEmpty })
            let earth = NowEarth.read(now, at: last, zone: utc)
            XCTAssertFalse(earth.countdownTimes.contains(""))
        }
    }

    /// In the partial syncs at both ends the core has no sync reading: the
    /// readings say so with `nil` (and NOW draws no Sun block, never a
    /// quarter word of its own).
    func testPartialSyncsHaveNoSunReading() {
        for instant in [clock.first.advanced(byMicroseconds: 86_400_000_000), clock.last.advanced(byMicroseconds: -86_400_000_000)] {
            XCTAssertNil(NowReading.read(clock, at: instant, focus: .helion).live?.sun)
            XCTAssertNil(WaveReading.read(clock, at: instant, focus: .helion, reach: 2, depth: 2).live?.sun)
            XCTAssertNotNil(NowReading.read(clock, at: instant, focus: .helion).pentad)
        }
    }

    // MARK: Moving along a wave

    /// The track is linear in POSITION, as the core's phase is, not in time:
    /// across an eclipse inside an Alpha or a Beta cycle the two used to part
    /// by minutes; now they agree to the phase's own resolution.
    func testTheTrackAgreesWithTheCoresPhase() throws {
        for index in 0 ... 8 {
            let level = try XCTUnwrap(Level(index))
            let cycle = try clock.cycle(level, at: a)
            let along = try XCTUnwrap(WaveTrack.cycles(in: clock, level: level, from: cycle.start, to: a))
            XCTAssertEqual(along, cycle.phase.value, accuracy: 1e-9, "level \(index)")
        }
    }
}
