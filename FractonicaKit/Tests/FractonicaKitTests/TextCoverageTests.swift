import FractonicaKit
import XCTest

/// Every public String API returns text wherever it is defined: across all 63
/// levels, all units, quarters, media, bands, forms, and the 22 clock levels
/// at the vectors. A wrapper that passed a wrong argument, or a buffer that
/// was too small, would show up here as an empty string.
final class TextCoverageTests: XCTestCase {
    private func assertText(_ text: String?, _ what: String, file: StaticString = #filePath, line: UInt = #line) {
        guard let text else { return XCTFail("\(what): no text", file: file, line: line) }
        XCTAssertFalse(text.isEmpty, "\(what): empty", file: file, line: line)
        XCTAssertFalse(text.contains("\0"), "\(what): a NUL inside", file: file, line: line)
        XCTAssertFalse(text.unicodeScalars.contains("\u{FFFD}"), "\(what): broken UTF-8", file: file, line: line)
    }

    func testStaticTextsOfAll63Levels() throws {
        let intervals = [SarosInterval.reference, clock.meanInterval, try clock.interval(at: Vector.b)]
        for level in Level.all {
            assertText(level.name, "\(level.index) name")
            assertText(level.word, "\(level.index) word")
            assertText(level.prefixText, "\(level.index) prefixText")
            assertText(level.description, "\(level.index) description")
            assertText(level.span.text(), "\(level.index) span")
            assertText(level.span.text(maxParts: 9), "\(level.index) span, all parts")

            // Pure wording.
            assertText(level.rateText(), "\(level.index) rateText")
            for digits in 2 ... 9 {
                assertText(level.rateText(digits: digits), "\(level.index) rateText(\(digits))")
            }
            for medium in Medium.allCases {
                assertText(level.lightSpanText(medium), "\(level.index) lightSpanText(\(medium))")
                assertText(level.lightSpanText(medium, withWord: false), "\(level.index) lightSpanText(\(medium))")
                XCTAssertTrue(level.lightSpanText(medium).hasSuffix(" light"))
                XCTAssertFalse(level.lightSpanText(medium, withWord: false).contains("light"))
            }
            assertText(level.prefixFactorsText, "\(level.index) prefixFactorsText")
            if level.child != nil {
                assertText(level.childrenText, "\(level.index) childrenText")
            } else {
                XCTAssertNil(level.childrenText)
            }
            if level.parent != nil {
                assertText(level.inParentText, "\(level.index) inParentText")
            } else {
                XCTAssertNil(level.inParentText)
            }
            // A cycle counted in a unit is defined down to the Blink, for units no coarser than the level.
            for unit in Unit.allCases {
                let defined = level.index <= Level.blink.index && unit.level >= level
                if defined {
                    assertText(level.countText(in: unit), "\(level.index) countText(in: \(unit))")
                } else {
                    XCTAssertNil(level.countText(in: unit), "\(level.index) countText(in: \(unit))")
                }
            }
            // The exact per-Blink ratio fits 64 bits to level 35.
            if level.index <= 35 {
                assertText(try level.cyclesPerBlink().text, "\(level.index) cyclesPerBlink")
            } else {
                XCTAssertThrows(.overflow, try level.cyclesPerBlink())
            }

            // The ladder in Earth units, on three intervals and at every precision.
            for interval in intervals {
                for digits in 1 ... 9 {
                    assertText(level.periodText(interval, digits: digits), "\(level.index) periodText")
                    assertText(level.frequencyText(interval, digits: digits), "\(level.index) frequencyText")
                    for medium in Medium.allCases {
                        assertText(
                            level.lengthText(interval, speed: medium.speed, digits: digits),
                            "\(level.index) lengthText(\(medium))"
                        )
                    }
                }
                assertText(try level.period(interval).text(.time), "\(level.index) period quantity")
                assertText(try level.frequency(interval).text(.frequency), "\(level.index) frequency quantity")
                assertText(try level.length(interval).text(.length), "\(level.index) length quantity")
                assertText(level.band(interval).name, "\(level.index) band")
                XCTAssertGreaterThan(level.periodSeconds(interval), 0)
                XCTAssertGreaterThan(level.frequencyHertz(interval), 0)
                XCTAssertGreaterThan(level.lengthMetres(interval), 0)
                // Period × frequency = 1, in doubles and in the 17-digit values.
                XCTAssertEqual(level.periodSeconds(interval) * level.frequencyHertz(interval), 1, accuracy: 1e-12)
                XCTAssertEqual(
                    try level.period(interval).value * level.frequency(interval).value, 1, accuracy: 1e-12
                )
            }
            // The default precision is four digits.
            XCTAssertEqual(level.periodText(), level.periodText(digits: 4))
            XCTAssertEqual(try level.period().text(.time), level.periodText())
            XCTAssertEqual(try level.frequency().text(.frequency), level.frequencyText())
            XCTAssertEqual(try level.length().text(.length), level.lengthText())
        }
    }

    func testCycleTextsOfEveryClockLevel() throws {
        for instant in [Vector.a, Vector.b, Vector.c, Vector.anchorPlusOneSecond, clock.first, clock.last] {
            for level in Level.clockLevels {
                let cycle = try clock.cycle(level, at: instant)
                assertText(cycle.name, "\(level.index) cycle name")
                assertText(cycle.shortName, "\(level.index) cycle short name")
                assertText(try level.cycleName(index: cycle.index), "\(level.index) cycleName")
                assertText(try level.cycleName(index: cycle.index, short: true), "\(level.index) cycleName short")
                XCTAssertEqual(try level.cycleName(index: cycle.index), cycle.name)
                assertText(cycle.quarter.name, "\(level.index) quarter")
                let next = try clock.nextThreshold(level, after: instant)
                assertText(next.quarter.name, "\(level.index) next threshold")
                if let nextInstant = next.instant {
                    assertText(try clock.span(from: instant, to: nextInstant).text(), "\(level.index) span to next")
                }
                assertText(try clock.span(from: cycle.start, to: cycle.end).text(), "\(level.index) cycle length")
            }
            for level in Level.all where !level.isClockLevel {
                XCTAssertThrows(.invalidArgument, try level.cycleName(index: 0))
            }
        }
    }

    func testDateAndPentadTextsInEveryForm() throws {
        for instant in [Vector.a, Vector.b, Vector.c, Vector.anchorPlusOneSecond, clock.first, clock.last] {
            let date = try clock.date(at: instant)
            for form in DateForm.allCases {
                for finest in Unit.allCases {
                    assertText(date.text(form, finest: finest), "date \(form) to \(finest)")
                }
                // A finest unit coarser than Delta is treated as Delta.
                XCTAssertEqual(date.text(form, finest: .alpha), date.text(form, finest: .delta))
            }
            assertText(date.stamp, "stamp")
            assertText(Fractonica.ascii(date.text(.full)), "ascii date")

            let pentad = try clock.pentad(at: instant)
            for form in PentadForm.allCases {
                // The numeral of the Hypopentad is empty: its square is the whole mark.
                if form == .numeral, pentad.isHypopentad {
                    XCTAssertEqual(pentad.text(form), "")
                    continue
                }
                assertText(pentad.text(form), "pentad \(form)")
                assertText(pentad.text(form, withHelion: true), "pentad \(form) with helion")
            }
            assertText(pentad.name, "pentad name")
            assertText(pentad.mark, "pentad mark")
            assertText(CivilTime(instant).isoText, "ISO text")
            assertText(instant.description, "instant description")
        }
    }

    func testTablesOfWords() {
        for unit in Unit.allCases {
            assertText(unit.symbol, "\(unit) symbol")
            assertText(unit.name, "\(unit) name")
            assertText(unit.name(plural: true), "\(unit) plural")
        }
        for quarter in Quarter.allCases {
            assertText(quarter.name, "\(quarter)")
            assertText(quarter.name(lowercase: true), "\(quarter) lowercase")
        }
        for medium in Medium.allCases {
            assertText(medium.id, "\(medium) id")
            assertText(medium.name, "\(medium) name")
            assertText(medium.phase, "\(medium) phase")
        }
        for band in Band.allCases {
            assertText(band.name, "\(band)")
        }
        for rate in TimeLapseRate.presets {
            assertText(rate.text, "rate \(rate)")
        }
        for n in 0 ... 30 {
            assertText(Fractonica.ordinal(n), "ordinal \(n)")
        }
        for n: UInt64 in [0, 1, 999, 1000, 4820, 58500, .max] {
            assertText(Fractonica.count(n), "count \(n)")
        }
        for n: Int64 in [.min, -1, 0, 1, .max] {
            assertText(Fractonica.count(signed: n), "signed count \(n)")
        }
        for kind in LevelKind.allCases {
            assertText(kind.text, "\(kind)")
        }
        for unit in Unit.allCases where unit != .alpha {
            assertText(unit.inParentText, "\(unit) inParentText")
        }
        assertText(Fractonica.lightWord, "the word light")
        assertText(BlinkRate(numerator: 0, denominator: 0).text, "an undefined rate") // "—"
        assertText(Span.zero.text(), "the zero span")
        assertText(FractonicaError.outOfRange.description, "error description")
        assertText(Fractonica.coreVersion, "core version")
        XCTAssertEqual(Fractonica.ascii(""), "")
        // A long text comes out whole (the buffer grows with the input).
        let long = String(repeating: "ε#5 34η 29ι 21λ 3ν · ", count: 400)
        XCTAssertEqual(Fractonica.ascii(long), String(repeating: "e#5 34h 29i 21l 3n . ", count: 400))
    }

    /// Pure mode shows no Earth unit (design/README.md, ruling 11). The pure
    /// wordings of every level are made of digits, Greek letters and the
    /// words "pB", "per", "Blink(s)", "light" only.
    func testPureWordingsCarryNoEarthUnit() {
        let allowedWords: Set<String> = [
            "pB", "per", "Blinks", "Blink", "light", "in", "of", "major", "unit", "between", "subBlink",
        ]
        func assertPure(_ text: String, file: StaticString = #filePath, line: UInt = #line) {
            for word in text.split(whereSeparator: { $0 == " " || $0 == "\u{202F}" || $0 == "\u{00A0}" }) {
                let latin = String(String.UnicodeScalarView(word.unicodeScalars.filter {
                    ("a" ... "z").contains($0) || ("A" ... "Z").contains($0)
                }))
                if latin.isEmpty { continue }
                XCTAssertTrue(allowedWords.contains(latin), "\"\(text)\" says \"\(latin)\"", file: file, line: line)
            }
        }
        for level in Level.all {
            assertPure(level.name)
            assertPure(level.span.text())
            assertPure(level.rateText())
            assertPure(level.rateText(digits: 4))
            for medium in Medium.allCases {
                assertPure(level.lightSpanText(medium))
            }
            for unit in Unit.allCases {
                level.countText(in: unit).map { assertPure($0) }
            }
            assertPure(level.kind.text)
            assertPure(level.prefixFactorsText)
            level.childrenText.map { assertPure($0) }
            level.inParentText.map { assertPure($0) }
        }
        for unit in Unit.allCases {
            unit.inParentText.map { assertPure($0) }
        }
        assertPure(Fractonica.count(58500))
        assertPure(Fractonica.count(signed: -4820))
        assertPure(Fractonica.lightWord)
    }
}
