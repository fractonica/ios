import XCTest
import FractonicaKit
@testable import Fractonica

/// WAVE and time travel: what the timeline reads from the core at SPEC
/// vector A, how a drag becomes an instant, how the tumblers step, what the
/// "go to" field reads, and that pure mode says nothing Earthly.
@MainActor
final class WaveTests: XCTestCase {
    private let clock = Catalogue.saros141
    private let a = Instant(unixSeconds: 1_791_460_800)!
    private var utc: TimeZone { TimeZone(identifier: "UTC")! }
    /// The narrow no-break space the core groups digits with.
    private let g = "\u{202F}"

    private func reading(focus: Level = .helion, at instant: Instant? = nil) -> WaveReading {
        WaveReading.read(clock, at: instant ?? a, focus: focus, reach: 1, depth: 2)
    }

    // MARK: The reading

    func testWaveReadingAtVectorA() throws {
        let wave = reading()
        XCTAssertEqual(wave.title, "Helion wave")
        XCTAssertEqual(wave.madeOf, "9 θ · 36ι")
        let live = try XCTUnwrap(wave.live)
        XCTAssertEqual(live.terms.map(\.text), ["α#6", "β#4", "γ#9", "δ#3", "ε#5", "34η", "29ι", "21λ", "3ν"])
        XCTAssertEqual(live.terms.map(\.unit), Unit.allCases)
        // The Helion under the hairline and its neighbours, named by the core.
        XCTAssertEqual(live.laps.map(\.offset), [-1, 0, 1])
        XCTAssertEqual(live.laps.map(\.name), ["33η", "34η", "35η"])
        XCTAssertEqual(live.nested.map(\.level.index), [7, 8])
        XCTAssertEqual(live.next.quarter, .end)
        XCTAssertEqual(live.nextSpan, "6ι 43λ")
        XCTAssertEqual(live.points.end, live.next.instant)

        // The Sun's lane: sync 4820, the 7th Helion of 19, Pentad II.
        let sun = try XCTUnwrap(live.sun)
        XCTAssertEqual(sun.number, "4\(g)820")
        XCTAssertEqual(sun.drift, "−6\u{202F}235λ") // whole Flavons, as NOW (was "−2η 23ι")
        XCTAssertEqual(sun.slot, 6)
        XCTAssertEqual(sun.pentads.map(\.start), [0, 5, 10, 15])
        XCTAssertEqual(sun.pentads.map(\.helions), [5, 5, 5, 4])
        XCTAssertEqual(sun.pentads.map(\.numeral), ["I", "II", "III", ""])
        XCTAssertEqual(sun.currentPentad, 1)
        XCTAssertEqual(sun.sync.next.quarter, .node)
        XCTAssertEqual(sun.nextSpan, "2η 24ι")

        // The list: two finer levels, the focus, four coarser, the Sun; soonest first.
        XCTAssertEqual(live.upcoming.count, 8)
        XCTAssertEqual(live.upcoming.map { $0.level?.name ?? "sun" }, ["ι", "θ", "η", "ζ", "sun", "ε", "δ", "γ"])
        XCTAssertEqual(live.upcoming.map(\.span),
                       ["11λ 9ν", "43λ 21ν", "6ι 43λ", "1η 33ι", "2η 24ι", "4η 24ι", "43η 6ι", "4ε 23η"])
        XCTAssertEqual(live.upcoming.map(\.threshold.quarter),
                       [.node, .node, .end, .peak, .node, .node, .end, .valley])
    }

    func testWaveForEveryFocusAndOutsideTheCatalogue() throws {
        for index in AppModel.focusRange {
            let focus = try XCTUnwrap(Level(index))
            let wave = WaveReading.read(clock, at: a, focus: focus, reach: 3, depth: 3)
            let live = try XCTUnwrap(wave.live, "focus \(index)")
            XCTAssertEqual(live.cycle.level, focus)
            XCTAssertFalse(wave.madeOf.isEmpty)
            XCTAssertTrue(live.laps.contains { $0.offset == 0 })
            XCTAssertFalse(live.laps.contains { $0.name.isEmpty })
            XCTAssertFalse(live.upcoming.isEmpty)
            // The neighbours tile: each ends where the next begins.
            for (earlier, later) in zip(live.laps, live.laps.dropFirst()) {
                XCTAssertEqual(earlier.cycle.end, later.cycle.start)
            }
        }
        let outside = reading(at: Instant(unixSeconds: 40_000_000_000)!)
        XCTAssertNil(outside.live)
        XCTAssertEqual(outside.outOfCatalogue, "OUT OF CATALOGUE · α#1 – α#18")
        // At the catalogue's first instant there is no cycle before.
        let first = try XCTUnwrap(reading(at: clock.first).live)
        XCTAssertEqual(first.laps.map(\.offset), [0, 1])
    }

    func testEarthTranslationAtVectorA() throws {
        let wave = reading()
        let earth = WaveEarth.read(wave, clock: clock, at: a, zone: utc)
        let fields = try XCTUnwrap(earth.fields)
        XCTAssertEqual([fields.weekday, fields.day, fields.month, fields.year, fields.hour, fields.minute,
                        fields.second, fields.zone], ["THU", "8", "OCT", "2026", "12", "00", "00", "UTC"])
        XCTAssertEqual(earth.dateLine, "THU 8 OCT 2026 · 12:00:00 UTC")
        // The design's figures (screen5_greg.png).
        XCTAssertEqual(earth.sunQuarters, ["8 OCT 01:34", "9 OCT 01:34", "10 OCT 01:34", "11 OCT 01:34"])
        XCTAssertEqual(earth.waveQuarters, ["09:08:51", "10:24:38", "11:40:25", "12:56:12"])
        XCTAssertEqual(earth.upcoming, ["12:01:28", "12:05:41", "12:56:12", "21:46:43", "9 OCT 01:34",
                                        "9 OCT 11:40", "17 OCT 14:11", "17 DEC 09:05"])
        // In another zone the fields move and the zone is named once.
        let paris = try XCTUnwrap(TimeZone(identifier: "Europe/Paris"))
        let local = try XCTUnwrap(WaveEarth.read(wave, clock: clock, at: a, zone: paris).fields)
        XCTAssertEqual(local.hour, "14")
        XCTAssertNotEqual(local.zone, "UTC")
    }

    // MARK: The wave as a line

    func testWaveTrackIsItsOwnInverse() throws {
        let helion = try clock.cycle(.helion, at: a)
        // Not moving is exact.
        XCTAssertEqual(WaveTrack.instant(in: clock, level: .helion, from: a, movedBy: 0), a)
        XCTAssertEqual(WaveTrack.cycles(in: clock, level: .helion, from: a, to: a), 0)
        // One whole cycle on is the same place in the next Helion.
        let next = WaveTrack.instant(in: clock, level: .helion, from: a, movedBy: 1)
        XCTAssertEqual(try clock.cycle(.helion, at: next).index, helion.index + 1)
        XCTAssertEqual(try XCTUnwrap(WaveTrack.cycles(in: clock, level: .helion, from: a, to: next)), 1, accuracy: 1e-9)
        XCTAssertEqual(try clock.date(at: next).eta, 35)
        // The track agrees with the core's phase.
        let toEnd = try XCTUnwrap(WaveTrack.cycles(in: clock, level: .helion, from: a, to: helion.end))
        XCTAssertEqual(toEnd, 1 - helion.phase.value, accuracy: 1e-6)
        let toStart = try XCTUnwrap(WaveTrack.cycles(in: clock, level: .helion, from: a, to: helion.start))
        XCTAssertEqual(toStart, -helion.phase.value, accuracy: 1e-6)
        // There and back, at every focus level, across cycle boundaries.
        for index in AppModel.focusRange {
            let level = try XCTUnwrap(Level(index))
            for cycles in [-2.75, -0.4, 0.3, 1.6] {
                let moved = WaveTrack.instant(in: clock, level: level, from: a, movedBy: cycles)
                let measured = try XCTUnwrap(WaveTrack.cycles(in: clock, level: level, from: a, to: moved))
                XCTAssertEqual(measured, cycles, accuracy: 1e-4, "level \(index)")
                let back = WaveTrack.instant(in: clock, level: level, from: moved, movedBy: -cycles)
                // Back within two grains of the core's phase (2⁻³² of a cycle:
                // 4 µs of a Helion, half a second of an Alpha), and 2 ms at least.
                let cycle = try clock.cycle(level, at: a)
                let grain = cycle.end.microseconds(since: cycle.start) / 2_147_483_648 + 2
                XCTAssertLessThanOrEqual(abs(back.microseconds(since: a)), max(2_000, grain), "level \(index)")
            }
        }
        // Time travel clamps to the catalogue.
        XCTAssertEqual(WaveTrack.instant(in: clock, level: .helion, from: a, movedBy: 1e12), clock.last)
        XCTAssertEqual(WaveTrack.instant(in: clock, level: .helion, from: a, movedBy: -1e12), clock.first)
        XCTAssertEqual(WaveTrack.instant(in: clock, level: .alpha, from: a, movedBy: 40), clock.last)
        XCTAssertNil(WaveTrack.cycles(in: clock, level: .helion, from: a, to: Instant(unixSeconds: 40_000_000_000)!))
    }

    func testSnappingToThresholdsAndToThePresent() throws {
        let width: CGFloat = 208
        let end = try XCTUnwrap(try clock.points(.helion, index: try clock.cycle(.helion, at: a).index).end)
        // Three points short of the Helion's End: it snaps there.
        let near = WaveTrack.instant(in: clock, level: .helion, from: end, movedBy: -3.0 / 208)
        XCTAssertEqual(WaveSnap.target(in: clock, level: .helion, at: near, now: a, cycleWidth: width, within: 6),
                       .threshold(end))
        // Ten points short: it stays.
        let far = WaveTrack.instant(in: clock, level: .helion, from: end, movedBy: -10.0 / 208)
        XCTAssertNil(WaveSnap.target(in: clock, level: .helion, at: far, now: a, cycleWidth: width, within: 6))
        // Within reach of the present, the present wins.
        let beside = WaveTrack.instant(in: clock, level: .helion, from: a, movedBy: 2.0 / 208)
        XCTAssertEqual(WaveSnap.target(in: clock, level: .helion, at: beside, now: a, cycleWidth: width, within: 6),
                       .present)
        // Already on a threshold: nothing to do.
        XCTAssertNil(WaveSnap.target(in: clock, level: .helion, at: end,
                                     now: a, cycleWidth: width, within: 6))
    }

    func testTheLitWaveMeetsTheHairline() throws {
        // The point of now, found by descending the core's running cycles,
        // lies under the hairline that the core's phase places: the two
        // agree for every focus level.
        for index in AppModel.focusRange {
            let focus = try XCTUnwrap(Level(index))
            let layout = WaveLayout.phone
            let live = try XCTUnwrap(WaveReading.read(clock, at: a, focus: focus, reach: 1, depth: 2).live)
            let start = layout.hairlineX - CGFloat(live.cycle.phase.value) * layout.cycleWidth
            let half = live.cycle.isInSecondHalf ? 1 : 0
            let carrier = WaveArcs.half(half, radius: layout.halfRadius, origin: CGPoint(x: start, y: layout.waveY))
            let nest = NestRenderer.buildHalf(carrier: carrier, level: focus, secondHalf: half == 1, stage: .current,
                                              running: live.nested, depth: 2)
            let point = try XCTUnwrap(nest.nowPoint, "focus \(index)")
            // A child arc swings to either side of its place on the axis by
            // at most its own diameter.
            let swing = CGFloat(carrier.child(m: focus.factor, local: 0, odd: half == 1).radius) * 2 + 1
            XCTAssertLessThanOrEqual(abs(point.x - layout.hairlineX), swing, "focus \(index)")
            // Half 0 of the wave runs above the axis, half 1 below it.
            let middle = carrier.cgPoint(at: 0.5)
            XCTAssertEqual(middle.y < layout.waveY, half == 0, "focus \(index)")
        }
    }

    func testPhoneLayoutIsTheDesigns() {
        // DESIGN.md §7, "Timeline".
        let layout = WaveLayout.phone
        XCTAssertEqual(layout.stampY, 136)
        XCTAssertEqual(layout.sunY, 232)
        XCTAssertEqual(layout.waveY, 380)
        XCTAssertEqual(layout.halfRadius, 52)
        XCTAssertEqual(layout.cycleWidth, 208)
        XCTAssertEqual(layout.waveY + 88 * layout.waveScale, 468)
        XCTAssertEqual(layout.limb.y, 522)
        XCTAssertEqual(layout.rowBaseline(0, earth: 0), 583)
        XCTAssertEqual(layout.rowBaseline(1, earth: 0) - layout.rowBaseline(0, earth: 0), 22.4, accuracy: 1e-9)
        // Earth mode keeps the list clear of the sigils (y 772).
        XCTAssertLessThan(layout.rowBaseline(7, earth: 1), 760)
        XCTAssertEqual(WaveLayout.desktop.maxRows, 8)
    }

    // MARK: Tumblers

    func testSteppingTheStamp() throws {
        func stamp(_ instant: Instant?) throws -> String { try clock.date(at: try XCTUnwrap(instant)).stamp }
        let step = { (unit: FractonicaKit.Unit, n: Int) in
            WaveStepping.instant(self.clock, from: self.a, field: .unit(unit), by: n, zone: nil)
        }
        XCTAssertEqual(try stamp(step(.helion, 1)), "α#6 β#4 γ#9 δ#3 ε#5 35η 29ι 21λ 3ν")
        XCTAssertEqual(try stamp(step(.preon, -1)), "α#6 β#4 γ#9 δ#3 ε#5 34η 28ι 21λ 3ν")
        XCTAssertEqual(try stamp(step(.blink, 22)), "α#6 β#4 γ#9 δ#3 ε#5 34η 29ι 22λ 0ν")
        // Beyond the catalogue a tumbler does not move.
        XCTAssertNil(step(.alpha, 40))
        XCTAssertNil(WaveStepping.instant(clock, from: clock.first, field: .unit(.blink), by: -1, zone: nil))

        // The ghosts are the term one step either way.
        XCTAssertEqual(StampGhosts.read(clock, at: a, field: .unit(.preon), zone: nil),
                       StampGhosts(above: "28ι", below: "30ι"))
        XCTAssertEqual(StampGhosts.read(clock, at: a, field: .unit(.nuclide), zone: nil),
                       StampGhosts(above: "ε#4", below: "ε#1"))
        XCTAssertEqual(StampGhosts.read(clock, at: clock.first, field: .unit(.alpha), zone: nil).above, nil)

        // Earth fields step by the calendar, and only with a zone.
        let month = WaveStepping.instant(clock, from: a, field: .earth(.month), by: 1, zone: utc)
        XCTAssertEqual(month.map { CivilTime($0).isoText }, "2026-11-08T12:00:00.000Z")
        let hour = WaveStepping.instant(clock, from: a, field: .earth(.hour), by: -13, zone: utc)
        XCTAssertEqual(hour.map { CivilTime($0).isoText }, "2026-10-07T23:00:00.000Z")
        XCTAssertNil(WaveStepping.instant(clock, from: a, field: .earth(.month), by: 1, zone: nil))
        XCTAssertNil(WaveStepping.instant(clock, from: a, field: .earth(.year), by: 4000, zone: utc))
        XCTAssertEqual(StampGhosts.read(clock, at: a, field: .earth(.month), zone: utc),
                       StampGhosts(above: "SEP", below: "NOV"))
        XCTAssertEqual(StampGhosts.read(clock, at: a, field: .earth(.month), zone: nil), StampGhosts())
    }

    // MARK: Go to

    func testGoToReadsWhatTheCoreReads() throws {
        let blink = try clock.instant(of: try clock.date(at: a))
        func go(_ text: String, zone: TimeZone? = nil) -> GoTo.Outcome {
            GoTo.resolve(text, clock: clock, at: a, earthZone: zone)
        }
        // Everything the core writes, and its ASCII shorthand.
        XCTAssertEqual(go("α#6 β#4 γ#9 δ#3 ε#5 34η 29ι 21λ 3ν"), .moment(blink))
        XCTAssertEqual(go("  a#6 b#4 g#9 d#3 e#5 34h 29i 21l 3n "), .moment(blink))
        XCTAssertEqual(go(try clock.date(at: a).text(.full)), .moment(blink))
        // A short form takes its coarse parts from the moment shown; parts
        // left out at the fine end are the start.
        let helion35 = try clock.instant(of: FractonicaDate(alpha: 6, beta: 4, gamma: 9, delta: 3, epsilon: 5, eta: 35))
        XCTAssertEqual(go("ε#5 35η"), .moment(helion35))
        XCTAssertEqual(go("δ#3 ε#5 35η"), .moment(helion35))
        // Beyond the catalogue it clamps and says so.
        XCTAssertEqual(go("α#19 β#1 γ#1 δ#1 ε#1"), .outOfCatalogue(clock.last))
        XCTAssertEqual(go("not a moment"), .unreadable)
        XCTAssertEqual(go(""), .unreadable)

        // An Earth date is read in Earth mode only.
        XCTAssertEqual(go("2026-10-08 12:00", zone: utc), .moment(a))
        XCTAssertEqual(go("2026-10-08T12:00:00Z", zone: utc), .moment(a))
        XCTAssertEqual(go("thu 8 oct 2026 · 12:00:00 UTC", zone: utc), .moment(a))
        XCTAssertEqual(go("2026-10-08", zone: utc), .moment(a.advanced(byMicroseconds: -43_200_000_000)))
        XCTAssertEqual(go("2026-10-08 14:00", zone: TimeZone(identifier: "Europe/Paris")), .moment(a))
        XCTAssertEqual(go("1500-01-01", zone: utc), .outOfCatalogue(clock.first))
        XCTAssertEqual(go("2026-13-08", zone: utc), .unreadable)
        XCTAssertEqual(go("2026-10-08 12:00"), .unreadable)
        // A stamp still reads in Earth mode.
        XCTAssertEqual(go("34h 29i", zone: utc), .moment(try clock.instant(of: {
            var date = try self.clock.date(at: self.a)
            date.lambda = 0
            date.nu = 0
            return date
        }())))
    }

    // MARK: The model

    func testTimeTravelIsGlobalAndClamps() throws {
        let model = AppModel(arguments: LaunchArguments(["--t", "1791460800", "--screen", "wave", "--mode", "pure"]))
        XCTAssertTrue(model.isAtNow)
        // The default tumbler is the unit just finer than the focus.
        XCTAssertEqual(model.activeStampField, .unit(.preon))
        model.selectStampField(by: 1)
        XCTAssertEqual(model.activeStampField, .unit(.flavon))
        model.selectStampField(by: 40)
        XCTAssertEqual(model.activeStampField, .unit(.blink))

        // Stepping a tumbler moves the cursor every screen reads.
        model.step(.unit(.helion), by: 1)
        XCTAssertFalse(model.isAtNow)
        XCTAssertEqual(try model.clock.date(at: model.instant).stamp, "α#6 β#4 γ#9 δ#3 ε#5 35η 29ι 21λ 3ν")
        XCTAssertEqual(InstrumentReading.read(model.clock, at: model.instant, focus: model.focus).live?.cycle.shortName,
                       "35η")
        model.stepStamp(by: -1)
        XCTAssertEqual(try model.clock.date(at: model.instant).nu, 2)
        // An Earth field is not stepped in pure mode.
        let before = model.instant
        model.step(.earth(.day), by: 1)
        XCTAssertEqual(model.instant, before)
        model.stampField = .earth(.day)
        XCTAssertEqual(model.activeStampField, .unit(.preon))
        model.setMode(.earth)
        XCTAssertEqual(model.activeStampField, .earth(.day))
        model.stepStamp(by: 1)
        XCTAssertEqual(model.instant.microseconds(since: before), 86_400_000_000)

        // Thresholds, one after another, and back.
        model.returnToNow()
        XCTAssertTrue(model.isAtNow)
        let points = try model.clock.points(of: model.clock.cycle(.helion, at: a))
        model.stepThreshold(by: 1)
        XCTAssertEqual(model.cursor, points.end)
        model.stepThreshold(by: -1)
        XCTAssertEqual(model.cursor, points.valley)

        // Dragging the wave, then letting go next to the present.
        model.scrub(alongWaveOf: .helion, from: a, cycles: 2.0 / 208)
        XCTAssertFalse(model.isAtNow)
        model.settleOnWave(cycleWidth: 208)
        XCTAssertTrue(model.isAtNow)
        model.scrub(alongWaveOf: .helion, from: a, cycles: 1e9)
        XCTAssertEqual(model.cursor, model.clock.last)

        // A cursor can be pinned at launch.
        let pinned = AppModel(arguments: LaunchArguments(["--t", "1791460800", "--cursor", "1791521430"]))
        XCTAssertEqual(pinned.cursor, Instant(unixSeconds: 1_791_521_430))
        XCTAssertEqual(try pinned.clock.span(from: pinned.now, to: pinned.instant).text(), "3η 12ι")
        XCTAssertEqual(try pinned.clock.span(from: pinned.now, to: pinned.instant).signedText(), "+3η 12ι")
    }

    // MARK: Pure mode

    /// Fragments that only an Earth translation would contain, and a number
    /// followed by an Earth unit.
    private let earthly = [":", "UTC", "GMT", "OCT", "2026", "Earth", "⊕", "%", "Hz", "THU"]
    private let earthUnit = #"[0-9] ?(s|ms|min|h|d|y|m|nm|µm|mm|km|Mm|Gm|Tm|Pm|Hz)\b"#

    func testPureWaveCarriesNoEarthText() throws {
        var texts: [String] = []
        for index in AppModel.focusRange {
            let wave = WaveReading.read(clock, at: a, focus: try XCTUnwrap(Level(index)), reach: 3, depth: 3)
            let live = try XCTUnwrap(wave.live)
            texts += [wave.title, wave.madeOf, wave.outOfCatalogue, live.nextSpan,
                      WaveSpeech.wave(wave, earth: nil), WaveSpeech.sun(wave, earth: nil),
                      WaveSpeech.moment(wave, earth: nil)]
            texts += live.terms.map(\.text) + live.terms.map(\.unit.name) + live.laps.map(\.name)
            texts += live.upcoming.flatMap { [WaveSpeech.rowLabel($0), WaveSpeech.rowValue($0, earthLine: nil), $0.span] }
            if let sun = live.sun {
                texts += [sun.number, sun.drift, sun.nextSpan] + sun.pentads.flatMap { [$0.numeral, $0.name] }
            }
            for unit in Unit.allCases {
                let ghosts = StampGhosts.read(clock, at: a, field: .unit(unit), zone: nil)
                texts += [ghosts.above ?? "", ghosts.below ?? ""]
            }
        }
        // The offset on the NOW mark.
        texts.append(try clock.span(from: a, to: a.advanced(byMicroseconds: 60_630_000_000)).signedText())
        texts.append(try clock.span(from: a, to: a.advanced(byMicroseconds: -60_630_000_000)).signedText())
        XCTAssertGreaterThan(texts.count, 500)
        for text in texts {
            for fragment in earthly {
                XCTAssertFalse(text.contains(fragment), "\"\(text)\" contains \"\(fragment)\"")
            }
            XCTAssertNil(text.range(of: earthUnit, options: .regularExpression), "\"\(text)\" names an Earth unit")
        }
        // And Earth mode does say it.
        let wave = reading()
        let earth = WaveEarth.read(wave, clock: clock, at: a, zone: utc)
        XCTAssertTrue(WaveSpeech.wave(wave, earth: earth).contains("Earth 12:56:12"))
        XCTAssertFalse(WaveSpeech.wave(wave, earth: earth).contains("⊕"), "the sign is drawn, the word is spoken")
        XCTAssertTrue(WaveSpeech.sun(wave, earth: earth).contains("Earth 9 OCT 01:34"))
        XCTAssertTrue(WaveSpeech.moment(wave, earth: earth).contains("THU 8 OCT 2026"))
        XCTAssertEqual(WaveSpeech.rowLabel(wave.live!.upcoming[0]), "Preon Node")
        XCTAssertEqual(WaveSpeech.rowLabel(wave.live!.upcoming[4]), "Sun Node")
    }
}
