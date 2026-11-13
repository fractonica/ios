import FractonicaKit
import XCTest

/// SPEC.md §15.6 typed in literally, the examples of §15.2 – §15.5, and the
/// round trips date <-> instant <-> text.
final class SpecNotationVectorTests: XCTestCase {
    private struct NotationVector {
        let name: String
        let instant: Instant
        let full: String
        let short: String
        let helionPair: [Int]
    }

    /// The table of §15.6.
    private let vectors = [
        NotationVector(
            name: "A", instant: Vector.a,
            full: "Alpha Hexafracton Valley, Beta Tetrafracton Valley, Gamma Nonafracton Valley, "
                + "Delta Trifracton End, ε#5 34η 29ι 21λ 3ν",
            short: "Delta Trifracton End ε#5 34η 29ι", helionPair: [13, 0]
        ),
        NotationVector(
            name: "B", instant: Vector.b,
            full: "Alpha Hexafracton Node, Beta Difracton End, Gamma Didecafracton Node, "
                + "Delta Trifracton Node, ε#2 21η 12ι 6λ 5ν",
            short: "Delta Trifracton Node ε#2 21η 12ι", helionPair: [5, 6]
        ),
        NotationVector(
            name: "C", instant: Vector.c,
            full: "Alpha Heptafracton Peak, Beta Difracton Peak, Gamma Monofracton End, "
                + "Delta Pentafracton Peak, ε#2 1η 23ι 1λ 21ν",
            short: "Delta Pentafracton Peak ε#2 1η 23ι", helionPair: [10, 3]
        ),
        NotationVector(
            name: "Anchor + 1 s", instant: Vector.anchorPlusOneSecond,
            full: "Alpha Hexafracton Peak, Beta Monofracton Peak, Gamma Monofracton Peak, "
                + "Delta Monofracton Peak, ε#1 1η 0ι 0λ 3ν",
            short: "Delta Monofracton Peak ε#1 1η 0ι", helionPair: [0, 0]
        ),
    ]

    func testSection15_6Table() throws {
        for vector in vectors {
            let date = try clock.date(at: vector.instant)
            XCTAssertEqual(date.text(.full, finest: .blink), vector.full, vector.name)
            XCTAssertEqual(date.text(.short, finest: .preon), vector.short, vector.name)
            XCTAssertEqual(try clock.odometer(.helion, at: vector.instant).digits, vector.helionPair, vector.name)
        }
    }

    func testStampAndFieldsAtA() throws {
        let date = try clock.date(at: Vector.a)
        // "The stamp at A is α#6 β#4 γ#9 δ#3 ε#5 34η 29ι 21λ 3ν."
        XCTAssertEqual(date.stamp, "α#6 β#4 γ#9 δ#3 ε#5 34η 29ι 21λ 3ν")
        XCTAssertEqual(date.text(.letters, finest: .preon), "α#6 β#4 γ#9 δ#3 ε#5 34η 29ι")
        XCTAssertEqual(date.text(.shortLetters, finest: .preon), "δ#3 ε#5 34η 29ι")
        XCTAssertEqual(date.text(.shortLetters, finest: .blink), "δ#3 ε#5 34η 29ι 21λ 3ν")

        XCTAssertEqual(Unit.allCases.map { date[$0] }, [6, 4, 9, 3, 5, 34, 29, 21, 3])
        XCTAssertEqual(
            [date.alphaQuarter, date.betaQuarter, date.gammaQuarter, date.deltaQuarter],
            [.valley, .valley, .valley, .end]
        )
        XCTAssertEqual(date.quarter(of: .delta), .end)
        XCTAssertNil(date.quarter(of: .helion))
    }

    func testSpansAtA() throws {
        // "At A the depth-7 end is 3,372.428 s away (§12), which is the span 6ι 43λ."
        let helionEnd = try XCTUnwrap(clock.nextThreshold(.helion, after: Vector.a).instant)
        let toEnd = try clock.span(from: Vector.a, to: helionEnd)
        XCTAssertEqual(toEnd.text(), "6ι 43λ")
        XCTAssertFalse(toEnd.isNegative)
        XCTAssertEqual(toEnd.parts(maxParts: 2).map(\.unit), [.preon, .flavon])
        XCTAssertEqual(toEnd.parts(maxParts: 2).map(\.count), [6, 43])

        // The depth-8 node is 340.937 s away (§12): 43.86 Flavons. A span is
        // counted, not rounded (§15.4), so the core says "43λ 21ν"; the "44λ"
        // of the design brief is that value rounded (DESIGN.md §13).
        let level7 = try XCTUnwrap(Level(7))
        let node = try XCTUnwrap(clock.nextThreshold(level7, after: Vector.a).instant)
        let toNode = try clock.span(from: Vector.a, to: node)
        XCTAssertEqual(toNode.text(), "43λ 21ν")
        XCTAssertEqual(toNode.text(maxParts: 1), "43λ")

        // DESIGN.md §9: the Sun's "NODE IN 2η 24ι".
        let sync = try clock.sync(at: Vector.a)
        let syncNode = try XCTUnwrap(sync.next.instant)
        XCTAssertEqual(try clock.span(from: Vector.a, to: syncNode).text(), "2η 24ι")

        // The sync's drift (−48 469.9899 s, §12) said as a span: from where
        // the sync would nominally start to where it does. 6 235.6 Flavons.
        let drift = try clock.span(from: sync.nominal, to: sync.start)
        XCTAssertTrue(drift.isNegative)
        XCTAssertEqual(drift.text(), "−2η 23ι")
        XCTAssertEqual(drift.blinks / Unit.flavon.blinks, 6235)

        // A span backwards is the same span with the minus (U+2212).
        XCTAssertEqual(try clock.span(from: helionEnd, to: Vector.a).text(), "−6ι 43λ")
        XCTAssertTrue(try clock.span(from: Vector.a, to: Vector.a).isZero)

        // A cycle's start to its end is its length exactly (fractonica.h, "THE TIME GRAIN").
        let preon = try clock.cycle(.preon, at: Vector.a)
        XCTAssertEqual(try clock.span(from: preon.start, to: preon.end).text(), "1ι")
        XCTAssertEqual(try clock.span(from: preon.start, to: preon.end), Level.preon.span)
    }

    func testSection15_4LevelLengths() throws {
        // "ζ = 11η, θ = 4ι, κ = 13λ, μ = 5ν, and ξ = 0.14ν"
        let expected: [(Int, String)] = [
            (0, "1α"), (1, "1β"), (2, "1γ"), (3, "1δ"), (4, "1ε"), (5, "11η"), (6, "1η"), (7, "4ι"),
            (8, "1ι"), (9, "13λ"), (10, "1λ"), (11, "5ν"), (12, "1ν"), (13, "0.14ν"),
        ]
        for (index, text) in expected {
            XCTAssertEqual(try XCTUnwrap(Level(index)).span.text(), text, "level \(index)")
        }
        XCTAssertEqual(Level.helion.span.blinks, 58_500)
        XCTAssertEqual(Level.helion.span.blinks, Unit.helion.blinks)
        // "Units with a zero count are skipped": 3η 5λ, never 3η 0ι 5λ.
        let span = Span(blinks: 3 * Unit.helion.blinks + 5 * Unit.flavon.blinks)
        XCTAssertEqual(span.text(), "3η 5λ")
        XCTAssertEqual(span.parts(maxParts: 3, keepZeros: true).map(\.count), [3, 0, 5])
        XCTAssertEqual(Span(isNegative: true, blinks: 2 * Unit.nuclide.blinks + 5 * Unit.helion.blinks).text(), "−2ε 5η")
    }

    func testSection15_2Ordinals() {
        XCTAssertEqual(Fractonica.ordinal(1), "Monofracton")
        XCTAssertEqual(Fractonica.ordinal(3), "Trifracton")
        XCTAssertEqual(Fractonica.ordinal(11), "Didecafracton")
        XCTAssertEqual(Fractonica.ordinal(18), "Octadecafracton")
        XCTAssertEqual(Fractonica.ordinal(25), "#25")
        XCTAssertEqual(Quarter.allCases.map(\.name), ["Peak", "Node", "Valley", "End"])
        XCTAssertEqual(Quarter.node.name(lowercase: true), "node")
    }

    func testSection15_3CycleNames() throws {
        // The cycles running at A, named by where they start in their Nuclide.
        XCTAssertEqual(try clock.cycle(.delta, at: Vector.a).name, "Delta Trifracton")
        XCTAssertEqual(try clock.cycle(.delta, at: Vector.a).shortName, "δ#3")
        XCTAssertEqual(try clock.cycle(.nuclide, at: Vector.a).name, "ε#5")
        XCTAssertEqual(try clock.cycle(.helion, at: Vector.a).name, "ε#5 34η")
        XCTAssertEqual(try clock.cycle(.helion, at: Vector.a).shortName, "34η")
        XCTAssertEqual(try clock.cycle(.preon, at: Vector.a).name, "ε#5 34η 29ι")
        // "a depth-8 cycle … (θ starts on multiples of 4ι)": 29ι is inside the θ that starts at 28ι.
        XCTAssertEqual(try clock.cycle(try XCTUnwrap(Level(7)), at: Vector.a).name, "ε#5 34η 28ι")
        // The catalogue is α#1 – α#18 (design/README.md, ruling 7).
        XCTAssertEqual(clock.cycleCount(.alpha), 18)
        XCTAssertEqual(try Level.alpha.cycleName(index: 0, short: true), "α#1")
        XCTAssertEqual(try Level.alpha.cycleName(index: clock.cycleCount(.alpha) - 1, short: true), "α#18")
        XCTAssertThrows(.invalidArgument, try XCTUnwrap(Level(22)).cycleName(index: 0))
    }

    func testSection15_5RatesAndPerBlink() throws {
        // "5ν (5×), λ (25×), 13λ (325×), ι (1,625×), 4ι (6,500×), η (58,500×), 11η (643,500×), then ε, δ, γ"
        let presets = TimeLapseRate.presets
        XCTAssertEqual(presets.count, 11)
        XCTAssertEqual(presets.prefix(8).map(\.factor), [1, 5, 25, 325, 1625, 6500, 58500, 643_500])
        XCTAssertEqual(presets.map(\.unit), [
            .blink, .blink, .flavon, .flavon, .preon, .preon, .helion, .helion, .nuclide, .delta, .gamma,
        ])
        XCTAssertEqual(presets.map(\.count), [0, 5, 1, 13, 1, 4, 1, 11, 1, 1, 1])
        XCTAssertEqual(TimeLapseRate.realTime.text, "real time")
        XCTAssertTrue(TimeLapseRate.realTime.isRealTime)
        XCTAssertEqual(presets[5].text, "4ι per Blink")

        // "ξ 7, ο 77, π 693 and ρ 2,772 pB."
        let expected: [(Int, UInt64)] = [(13, 7), (14, 77), (15, 693), (16, 2772)]
        for (index, rate) in expected {
            let perBlink = try XCTUnwrap(Level(index)).cyclesPerBlink()
            XCTAssertEqual(perBlink.numerator, rate)
            XCTAssertEqual(perBlink.denominator, 1)
        }
        XCTAssertEqual(try XCTUnwrap(Level(13)).cyclesPerBlink().text, "7 pB")
        XCTAssertEqual(try XCTUnwrap(Level(16)).cyclesPerBlink().text, "2\u{202F}772 pB")
        XCTAssertEqual(try Level.helion.cyclesPerBlink(), BlinkRate(numerator: 1, denominator: 58500))
        XCTAssertEqual(try Level.helion.cyclesPerBlink().text, "1 per 58\u{202F}500 Blinks")
        // "A 110 Hz tone is 34.2 pB" (T(ν) on the mean interval, §16.5).
        XCTAssertEqual(BlinkRate(numerator: 110 * 77_894_856_196, denominator: 250_529_296_875).text, "34.2 pB")
        XCTAssertThrows(.overflow, try XCTUnwrap(Level(36)).cyclesPerBlink())
    }

    // MARK: Pure wording (fractonica.h "Pure wording"; design/README.md rulings 2 and 3)

    func testPureWording() throws {
        XCTAssertEqual(Fractonica.count(999), "999")
        XCTAssertEqual(Fractonica.count(58500), "58\u{202F}500")
        XCTAssertEqual(Fractonica.count(4820), "4\u{202F}820")

        // "The Helion (level 6) is 58 500ν in Blinks, 2 340λ in Flavons, 36ι in Preons and 1η in Helions"
        XCTAssertEqual(Level.helion.countText(in: .blink), "58\u{202F}500ν")
        XCTAssertEqual(Level.helion.countText(in: .flavon), "2\u{202F}340λ")
        XCTAssertEqual(Level.helion.countText(in: .preon), "36ι")
        XCTAssertEqual(Level.helion.countText(in: .helion), "1η")
        XCTAssertEqual(try XCTUnwrap(Level(5)).countText(in: .helion), "11η")
        XCTAssertNil(Level.helion.countText(in: .nuclide))
        XCTAssertNil(try XCTUnwrap(Level(13)).countText(in: .blink))

        // Rates: "1 per 58 500 Blinks", "2 772 pB", "1.420 × 10¹⁴ pB".
        XCTAssertEqual(Level.helion.rateText(), "1 per 58\u{202F}500 Blinks")
        XCTAssertEqual(Level.blink.rateText(), "1 pB")
        XCTAssertEqual(try XCTUnwrap(Level(13)).rateText(), "7 pB")
        XCTAssertEqual(try XCTUnwrap(Level(16)).rateText(), "2\u{202F}772 pB")
        let zeta1 = try XCTUnwrap(Level(29))
        XCTAssertEqual(zeta1.rateText(), "142\u{202F}033\u{202F}641\u{202F}750\u{202F}000 pB")
        XCTAssertEqual(zeta1.rateText(digits: 4), "1.420 × 10¹⁴ pB")

        // "One Helion in each medium of S16.3 reads 1η, 24ι 1λ, 3.5ν, 2.05ξ, 5.15ο, 1.80ο, 6.15χ."
        XCTAssertEqual(
            Medium.allCases.map { Level.helion.lightSpanText($0, withWord: false) },
            ["1η", "24ι 1λ", "3.5ν", "2.05ξ", "5.15ο", "1.80ο", "6.15χ"]
        )
        XCTAssertEqual(Level.helion.lightSpanText(), "1η light")
        XCTAssertEqual(Level.helion.lightSpanText(.bounded), "24ι 1λ light")
        XCTAssertEqual(try Level.helion.lightSpanText(speed: .light, withWord: false), "1η")
        XCTAssertThrows(.invalidArgument, try Level.helion.lightSpanText(speed: Speed(numerator: 0)))
    }

    // MARK: Round trips

    func testFullDateReadsBack() throws {
        for vector in vectors {
            let date = try clock.date(at: vector.instant)
            for form in [DateForm.full, .letters] {
                let text = date.text(form, finest: .blink)
                let parsed = try FractonicaDate.parse(text)
                XCTAssertEqual(parsed.finest, .blink)
                // The Blink the text names holds the instant: it starts at or
                // before it, and the date read at its start is the same date.
                let blinkStart = try clock.instant(of: parsed.date)
                XCTAssertLessThanOrEqual(blinkStart, vector.instant, vector.name)
                XCTAssertEqual(try clock.date(at: blinkStart), date, vector.name)
                XCTAssertEqual(try clock.cycle(.blink, at: vector.instant).start, blinkStart, vector.name)
            }
            // The ASCII of a stamp reads back too.
            let ascii = Fractonica.ascii(date.stamp)
            XCTAssertTrue(ascii.utf8.allSatisfy { $0 < 0x80 })
            XCTAssertEqual(try clock.instant(of: FractonicaDate(parsing: ascii)), try clock.instant(of: date))
        }
        XCTAssertEqual(Fractonica.ascii("α#6 β#4 γ#9 δ#3 ε#5 34η 29ι 21λ 3ν"), "a#6 b#4 g#9 d#3 e#5 34h 29i 21l 3n")
    }

    func testShortFormsNeedContext() throws {
        let date = try clock.date(at: Vector.a)
        let short = date.text(.shortLetters, finest: .preon) // "δ#3 ε#5 34η 29ι"
        XCTAssertThrows(.unparsable, try FractonicaDate(parsing: short))
        let parsed = try FractonicaDate.parse(short, context: date)
        XCTAssertEqual(parsed.finest, .preon)
        XCTAssertEqual(parsed.date.alpha, 6)
        XCTAssertEqual(parsed.date.gamma, 9)
        XCTAssertEqual(parsed.date.lambda, 0) // parts missing at the fine end are the start
        XCTAssertEqual(try clock.instant(of: parsed.date), try clock.cycle(.preon, at: Vector.a).start)

        // A leading Pentad is skipped (SPEC §15.3).
        let withPentad = try FractonicaDate(parsing: "⬠II δ#3 ε#5 34η 29ι", context: date)
        XCTAssertEqual(withPentad, parsed.date)
        XCTAssertThrows(.unparsable, try FractonicaDate(parsing: "not a date"))
    }

    func testDateRoundTripsAcrossTheCatalogue() throws {
        // An instant -> its date -> the start of its Blink -> the same date,
        // at every eclipse and at instants spread between them.
        var samples: [Instant] = []
        for ordinal in 0 ..< clock.eclipseCount - 1 {
            let start = try XCTUnwrap(clock.eclipse(ordinal))
            let end = try XCTUnwrap(clock.eclipse(ordinal + 1))
            let length = end.microseconds(since: start)
            samples += [start, start.advanced(byMicroseconds: length / 3), start.advanced(byMicroseconds: length - 1)]
        }
        XCTAssertEqual(samples.count, 3 * 69)
        for instant in samples {
            let date = try clock.date(at: instant)
            let blinkStart = try clock.instant(of: date)
            XCTAssertLessThanOrEqual(blinkStart, instant)
            XCTAssertEqual(try clock.date(at: blinkStart), date)
            XCTAssertEqual(try FractonicaDate(parsing: date.stamp).stamp, date.stamp)
        }
    }

    func testInvalidDates() throws {
        var date = try clock.date(at: Vector.a)
        date.eta = 78 // a Nuclide has 77 Helions
        XCTAssertThrows(.invalidArgument, try clock.instant(of: date))
        date = try clock.date(at: Vector.a)
        date.alpha = 19 // Saros 141 has 18 Alphas
        XCTAssertThrows(.outOfRange, try clock.instant(of: date))
        date.alpha = 0
        XCTAssertThrows(.invalidArgument, try clock.instant(of: date))
    }

    // MARK: Stepping one term of the stamp

    func testSteppingAUnitKeepsTheFinerTerms() throws {
        let stamp = { (instant: Instant) in try clock.date(at: instant).stamp }
        // α#6 β#4 γ#9 δ#3 ε#5 34η 29ι 21λ 3ν
        XCTAssertEqual(
            try stamp(clock.instant(byStepping: .helion, by: 1, from: Vector.a)),
            "α#6 β#4 γ#9 δ#3 ε#5 35η 29ι 21λ 3ν"
        )
        XCTAssertEqual(
            try stamp(clock.instant(byStepping: .helion, by: -1, from: Vector.a)),
            "α#6 β#4 γ#9 δ#3 ε#5 33η 29ι 21λ 3ν"
        )
        XCTAssertEqual(
            try stamp(clock.instant(byStepping: .preon, by: 1, from: Vector.a)),
            "α#6 β#4 γ#9 δ#3 ε#5 34η 30ι 21λ 3ν"
        )
        XCTAssertEqual(
            try stamp(clock.instant(byStepping: .blink, by: -3, from: Vector.a)),
            "α#6 β#4 γ#9 δ#3 ε#5 34η 29ι 21λ 0ν"
        )
        // 44 Helions on, the 77 of this Nuclide are used up: the next Nuclide
        // is the first of the next Delta.
        XCTAssertEqual(
            try stamp(clock.instant(byStepping: .helion, by: 44, from: Vector.a)),
            "α#6 β#4 γ#9 δ#4 ε#1 1η 29ι 21λ 3ν"
        )
        XCTAssertEqual(
            try stamp(clock.instant(byStepping: .alpha, by: 1, from: Vector.a)),
            "α#7 β#4 γ#9 δ#3 ε#5 34η 29ι 21λ 3ν"
        )
        // A zero step lands on the start of the Blink that holds the instant.
        XCTAssertEqual(
            try clock.instant(byStepping: .flavon, by: 0, from: Vector.a),
            try clock.cycle(.blink, at: Vector.a).start
        )
        XCTAssertThrows(.outOfRange, try clock.instant(byStepping: .alpha, by: -6, from: Vector.a))
        XCTAssertThrows(.outOfRange, try clock.instant(byStepping: .alpha, by: 13, from: Vector.a))
    }
}
