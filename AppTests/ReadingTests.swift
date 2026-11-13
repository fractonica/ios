import XCTest
import FractonicaKit
@testable import Fractonica

/// The readings the screens draw, held against SPEC test vector A
/// (Unix 1791460800 s, stamp `α#6 β#4 γ#9 δ#3 ε#5 34η 29ι 21λ 3ν`).
final class ReadingTests: XCTestCase {
    private let clock = Catalogue.saros141
    private let a = Instant(unixSeconds: 1_791_460_800)!

    func testHelionInstrumentAtVectorA() throws {
        let reading = InstrumentReading.read(clock, at: a, focus: .helion, depth: 3)
        let live = try XCTUnwrap(reading.live)
        XCTAssertEqual(reading.title, "34η")
        XCTAssertEqual(live.odometer.digits, [13, 0])
        // θ is 8 of 9: eight beads lit on the Helion's carrier.
        XCTAssertEqual(reading.beadCount, 9)
        XCTAssertEqual(reading.beadsLit, 8)
        // 36 Preons graduate the bezel; 29 are complete (the 29ι of the reading).
        XCTAssertEqual(reading.graduationCount, 36)
        XCTAssertEqual(reading.graduationsPerBead, 4)
        XCTAssertEqual(live.graduationsLit, 29)
        XCTAssertEqual(reading.slotCount, 18)
        XCTAssertEqual(live.nested.map(\.level.index), [7, 8, 9])
        XCTAssertEqual(live.nextThreshold.quarter, .end)
        XCTAssertEqual(live.nextSpan, "6ι 43λ")
    }

    func testCounterRingsAtVectorA() throws {
        let reading = InstrumentReading.read(clock, at: a, focus: .helion)
        // One ring per ancestor, nearest first: ζ ε δ γ β α.
        XCTAssertEqual(reading.counters.map(\.level.name), ["ζ", "ε", "δ", "γ", "β", "α"])
        let zeta = try XCTUnwrap(reading.counters.first)
        // ζ's ring is the Helion's sibling counter: 1 of 11 lit.
        XCTAssertEqual(zeta.slots, 11)
        XCTAssertEqual(zeta.live?.child.local, 0)
        XCTAssertFalse(zeta.isMajor)
        XCTAssertEqual(reading.counters.filter(\.isMajor).count, 4)
    }

    func testSunAtVectorA() throws {
        let sun = try XCTUnwrap(InstrumentReading.read(clock, at: a, focus: .helion).live?.sun)
        XCTAssertEqual(sun.sync.number, 4820)
        XCTAssertEqual(sun.odometer.digits, [5, 11, 13])
        XCTAssertEqual(sun.slots, 19)
        XCTAssertEqual(sun.pentadStarts, [0, 5, 10, 15])
        // Pentad II, 2nd Helion: the seventh Helion of the sync.
        XCTAssertEqual(sun.currentSlot, 6)
        // A focus coarser than the Helion has no Sun's ring.
        XCTAssertFalse(InstrumentReading.read(clock, at: a, focus: .nuclide).showsSunRing)
        XCTAssertNil(InstrumentReading.read(clock, at: a, focus: .nuclide).live?.sun)
    }

    func testNowReadingAtVectorA() throws {
        let reading = NowReading.read(clock, at: a, focus: .helion)
        let live = try XCTUnwrap(reading.live)
        XCTAssertEqual(live.terms, ["ε#5", "34η", "29ι", "21λ", "3ν"])
        XCTAssertEqual(live.majors.map(\.name), ["Alpha Hexafracton", "Beta Tetrafracton", "Gamma Nonafracton", "Delta Trifracton"])
        XCTAssertEqual(live.majors.map(\.quarter), [.valley, .valley, .valley, .end])
        XCTAssertEqual(live.countdowns.map(\.level.index), [6, 7])
        // The core counts spans, it does not round them: 43λ 21ν, not 44λ.
        XCTAssertEqual(live.countdowns.map(\.span), ["6ι 43λ", "43λ 21ν"])
        XCTAssertEqual(live.countdowns.map(\.threshold.quarter), [.end, .node])
        XCTAssertEqual(live.countdowns.map { $0.cycle.local + 1 }, [1, 8])
        XCTAssertEqual(live.countdowns.map(\.cycle.siblings), [11, 9])
        let sun = try XCTUnwrap(live.sun)
        XCTAssertEqual(Fractonica.ascii(sun.number).filter(\.isNumber), "4820")
        // The drift in whole Flavons, cut (frc_format_span_in_unit): the
        // design's single-unit figure (it prints −6 236λ, rounded); was the
        // two-part span "−2η 23ι" before the core had the form.
        XCTAssertEqual(sun.drift, "−6\u{202F}235λ")
        XCTAssertEqual(sun.nextSpan, "2η 24ι")
        XCTAssertEqual(reading.pentad?.name, "Pentad II")
        XCTAssertEqual(reading.pentad?.helion, 2)
        XCTAssertEqual(reading.pentadNumeral, "II")
        // Next thresholds: the Sun and the four coarser levels, soonest first.
        XCTAssertEqual(live.upcoming.map { $0.level?.name ?? "sun" }, ["ζ", "sun", "ε", "δ", "γ"])
        XCTAssertEqual(live.upcoming.map(\.span), ["1η 33ι", "2η 24ι", "4η 24ι", "43η 6ι", "4ε 23η"])
    }

    func testEveryFocusLevelReads() throws {
        for index in AppModel.focusRange {
            let level = try XCTUnwrap(Level(index))
            let reading = InstrumentReading.read(clock, at: a, focus: level, depth: 3)
            let live = try XCTUnwrap(reading.live, "\(level)")
            XCTAssertEqual(live.nested.count, 3, "\(level)")
            XCTAssertEqual(reading.counters.count, index, "\(level)")
            XCTAssertTrue((1 ... reading.beadCount).contains(reading.beadsLit), "\(level)")
            XCTAssertTrue((0 ..< reading.graduationCount).contains(live.graduationsLit), "\(level)")
            XCTAssertFalse(reading.title.isEmpty)
            XCTAssertNotNil(NowReading.read(clock, at: a, focus: level).live, "\(level)")
        }
    }

    func testOutOfCatalogue() throws {
        let far = Instant(unixSeconds: 40_000_000_000)!
        XCTAssertFalse(clock.contains(far))
        let reading = InstrumentReading.read(clock, at: far, focus: .helion)
        XCTAssertNil(reading.live)
        // The instrument stays engraved: the rings are there, nothing is lit.
        XCTAssertEqual(reading.counters.count, 6)
        XCTAssertTrue(reading.counters.allSatisfy { $0.live == nil })
        XCTAssertEqual(reading.beadsLit, 0)
        let now = NowReading.read(clock, at: far, focus: .helion)
        XCTAssertNil(now.live)
        XCTAssertEqual(now.outOfCatalogue, "OUT OF CATALOGUE · α#1 – α#18")
    }

    func testEarthTexts() throws {
        let utc = try XCTUnwrap(TimeZone(identifier: "UTC"))
        XCTAssertTrue(EarthText.dateLine(a, zone: utc).hasPrefix("THU 8 OCT 2026 · 12:00:00"))
        let reading = NowReading.read(clock, at: a, focus: .helion)
        let earth = NowEarth.read(reading, at: a, zone: utc)
        XCTAssertEqual(earth.countdownTimes, ["12:56:12", "12:05:41"])
        XCTAssertEqual(earth.countdownDurations, ["56 min 12 s", "5 min 41 s"])
        XCTAssertEqual(earth.syncStart, "7 OCT 01:34")
        XCTAssertEqual(Fractonica.ascii(earth.driftSeconds).replacingOccurrences(of: " ", with: ""), "-48469.99s")
        XCTAssertEqual(earth.syncNext, "9 OCT 01:34:05")
        let layer = EarthLayer.read(InstrumentReading.read(clock, at: a, focus: .helion), clock: clock, at: a, zone: utc)
        XCTAssertEqual(layer.bezelTimes[.end], "12:56")
        XCTAssertEqual(layer.bezelTimes[.node], "10:24")
        // Four civil days hang on the Sun's ring: midnights of the 8th to the 11th.
        XCTAssertEqual(layer.sunTicks.compactMap(\.label), ["8", "9", "10", "11"])
    }
}

/// Pure mode says nothing Earthly, also to assistive technology.
final class PureSpeechTests: XCTestCase {
    private let clock = Catalogue.saros141
    private let a = Instant(unixSeconds: 1_791_460_800)!
    /// Fragments that only an Earth translation would contain.
    private let earthly = [":", "UTC", "GMT", "OCT", "THU", "2026", "Earth", "⊕", "%", "Hz"]
    /// A number followed by an Earth unit: `12 s`, `5 min`, `4 h`.
    private let earthUnit = #"[0-9] (s|min|h|d|y|m|nm|Hz)\b"#

    func testPureSpeechCarriesNoEarthText() throws {
        for index in AppModel.focusRange {
            let level = try XCTUnwrap(Level(index))
            let reading = InstrumentReading.read(clock, at: a, focus: level)
            let now = NowReading.read(clock, at: a, focus: level)
            var spoken = [
                InstrumentSpeech.heroLabel(reading),
                InstrumentSpeech.heroValue(reading, outOfCatalogue: now.outOfCatalogue, zone: nil),
                InstrumentSpeech.sunLabel,
                InstrumentSpeech.sunValue(now, zone: nil),
                now.live?.date.text(.full) ?? "",
                now.pentad?.text(.full, withHelion: true) ?? "",
            ]
            for counter in reading.counters {
                spoken.append(InstrumentSpeech.counterLabel(counter))
                spoken.append(InstrumentSpeech.counterValue(counter, outOfCatalogue: now.outOfCatalogue))
            }
            for text in spoken {
                for fragment in earthly {
                    XCTAssertFalse(text.contains(fragment), "\"\(text)\" contains \"\(fragment)\" (focus \(index))")
                }
                XCTAssertNil(text.range(of: earthUnit, options: .regularExpression), "\"\(text)\" (focus \(index))")
            }
        }
    }

    func testEarthSpeechAddsTheTranslation() throws {
        let utc = try XCTUnwrap(TimeZone(identifier: "UTC"))
        let reading = InstrumentReading.read(clock, at: a, focus: .helion)
        let now = NowReading.read(clock, at: a, focus: .helion)
        XCTAssertEqual(InstrumentSpeech.heroLabel(reading), "Helion ring")
        XCTAssertEqual(InstrumentSpeech.heroValue(reading, outOfCatalogue: "", zone: nil), "ε#5 34η, End in 6ι 43λ")
        XCTAssertEqual(InstrumentSpeech.heroValue(reading, outOfCatalogue: "", zone: utc), "ε#5 34η, End in 6ι 43λ, Earth 12:56:12")
        XCTAssertTrue(InstrumentSpeech.sunValue(now, zone: nil).hasSuffix("Pentad II, 2nd Helion, Node in 2η 24ι"))
        XCTAssertEqual(InstrumentSpeech.counterLabel(reading.counters[1]), "Nuclide ring")
        XCTAssertEqual(InstrumentSpeech.counterValue(reading.counters[2], outOfCatalogue: ""), "Delta Trifracton, End")
    }
}
