import XCTest
import FractonicaKit
@testable import Fractonica

/// LADDER and LENS: what they read from the core at SPEC vector A, where the
/// wheel puts things, and that pure mode says nothing Earthly.
final class LadderLensTests: XCTestCase {
    private let clock = Catalogue.saros141
    private let a = Instant(unixSeconds: 1_791_460_800)!
    private var utc: TimeZone { TimeZone(identifier: "UTC")! }
    /// The narrow no-break space the core groups digits with.
    private let g = "\u{202F}"

    // MARK: The ladder

    func testLadderRungsAtVectorA() throws {
        let ladder = LadderReading.read(clock, at: a, earth: false)
        XCTAssertEqual(ladder.rungs.count, 63)
        XCTAssertEqual(ladder.rungs.map(\.level.index), Array(0 ... 62))
        // Pure mode builds no Earth value at all.
        XCTAssertTrue(ladder.rungs.allSatisfy { $0.earth == nil })

        let helion = ladder[.helion]
        XCTAssertEqual(helion.name, "η")
        XCTAssertEqual(helion.unitName, "Helion")
        XCTAssertEqual(helion.length, "1η")
        XCTAssertEqual(helion.rate, "1 per 58\(g)500 Blinks")
        XCTAssertEqual(helion.madeOf, "36ι")
        XCTAssertEqual(helion.inParent, "11 in ζ")
        XCTAssertEqual(helion.caption, "unit · no band · 11 in ζ")
        XCTAssertEqual(helion.sizeWordings, ["1η"])
        XCTAssertTrue(helion.isFocusable)

        XCTAssertNil(ladder[.alpha].inParent)
        XCTAssertEqual(ladder[.alpha].caption, "major · no band")
        XCTAssertEqual(ladder[.blink].madeOf, "7 ξ")
        XCTAssertEqual(ladder.rungs[5].length, "11η")
        XCTAssertEqual(ladder.rungs[13].sizeWordings.first, "7 pB")
        XCTAssertNil(ladder.rungs[13].length)
        XCTAssertNil(ladder.rungs[62].madeOf)

        // ζ1 is the one rung of visible light; its rate is the design's figure.
        XCTAssertEqual(ladder.rungs.filter(\.isVisibleLight).map(\.name), ["ζ1"])
        let zeta1 = ladder.rungs[29]
        XCTAssertEqual(zeta1.sizeWordings.first, "142\(g)033\(g)641\(g)750\(g)000 pB")
        // The kind is the core's word (ruling 4): "sub-Blink", no longer the app's own "sub".
        XCTAssertEqual(zeta1.caption, "sub-Blink · visible · 7 in ε1")
        XCTAssertEqual(zeta1.madeOf, "11 η1")
        XCTAssertFalse(zeta1.isFocusable)
        // Sixteen digits are written to four.
        XCTAssertEqual(ladder.rungs[30].sizeWordings.last, "1.562 × 10¹⁵ pB")
    }

    func testLadderEarthValuesAreTheDesigns() throws {
        let ladder = LadderReading.read(clock, at: a, earth: true)
        let zeta1 = try XCTUnwrap(ladder.rungs[29].earth)
        XCTAssertEqual([zeta1.period, zeta1.frequency, zeta1.length], ["2.189 fs", "456.8 THz", "656.3 nm"])
        let helion = try XCTUnwrap(ladder[.helion].earth)
        XCTAssertEqual([helion.period, helion.frequency, helion.length], ["5.052 h", "54.98 µHz", "5.453 Tm"])
        // Outside the catalogue the ladder is laid from the reference interval.
        XCTAssertEqual(LadderReading.interval(clock, at: Instant(unixSeconds: 40_000_000_000)!), .reference)
    }

    func testBandRule() throws {
        let interval = LadderReading.interval(clock, at: a)
        let edges = try XCTUnwrap(Band.visible.edgeTexts)
        XCTAssertEqual(edges.low, "400 THz")
        XCTAssertEqual(edges.high, "790 THz")
        // SPEC §16.2's figures, every edge (the core's edges, two digits).
        XCTAssertEqual(Band.allCases.compactMap(\.edgeTexts).map { "\($0.low) – \($0.high)" }, [
            "20 Hz – 20 kHz", "20 kHz – 300 MHz", "300 MHz – 300 GHz", "300 GHz – 400 THz", "400 THz – 790 THz",
            "790 THz – 30 PHz", "30 PHz – 30 EHz", "30 EHz – 3.4 × 10²⁹ Hz",
        ])
        let neighbours = try XCTUnwrap(Band.visible.neighbours)
        XCTAssertEqual(neighbours.below, .infrared)
        XCTAssertEqual(neighbours.above, .ultraviolet)
        XCTAssertEqual(Band.audible.neighbours?.below, .noBand)
        XCTAssertEqual(Band.gamma.neighbours?.above, .noBand)
        XCTAssertNil(Band.noBand.neighbours)
        XCTAssertNil(Band.noBand.edgeTexts)
        // ζ1, 456.8 THz, sits a fifth of the way up the visible band (log scale).
        let place = try XCTUnwrap(ShimCoreGaps.placeInBand(try XCTUnwrap(Level(29)), interval: interval))
        XCTAssertEqual(place, 0.195, accuracy: 0.002)
        XCTAssertNil(ShimCoreGaps.placeInBand(.helion, interval: interval))
        // Every banded rung lies inside its band.
        for level in Level.all where level.band(interval) != .noBand {
            let place = try XCTUnwrap(ShimCoreGaps.placeInBand(level, interval: interval), "\(level)")
            XCTAssertTrue((0 ... 1).contains(place), "\(level)")
        }
    }

    func testWheelGeometry() throws {
        for geometry in [LadderGeometry.phone, .desktop] {
            XCTAssertEqual(geometry.rowY(offset: 0), geometry.focusY)
            XCTAssertEqual(geometry.rimX(atY: geometry.focusY), geometry.rimX, accuracy: 0.001)
            for offset in stride(from: CGFloat(-6), through: 6, by: 0.25) {
                XCTAssertEqual(geometry.offset(atY: geometry.rowY(offset: offset)), offset, accuracy: 0.0001)
            }
            // The window: the focused rung and `span` on each side, fewer at the ends.
            XCTAssertEqual(geometry.visibleLevels(at: 29).count, 2 * geometry.span + 1)
            XCTAssertEqual(geometry.visibleLevels(at: 0).first, .alpha)
            XCTAssertEqual(geometry.visibleLevels(at: 0).count, geometry.span + 1)
            XCTAssertEqual(geometry.visibleLevels(at: 62).last?.index, 62)
            XCTAssertEqual(geometry.level(atY: geometry.rowY(offset: 3), position: 29)?.index, 32)
            XCTAssertNil(geometry.level(atY: geometry.rowY(offset: -3), position: 1))
            // The spine maps the 63 rungs onto its length and back.
            XCTAssertEqual(geometry.spineY(0), geometry.spineTop)
            XCTAssertEqual(geometry.spineY(62), geometry.spineBottom)
            XCTAssertEqual(geometry.spinePosition(atY: geometry.spineY(29)), 29, accuracy: 0.0001)
            XCTAssertEqual(geometry.spinePosition(atY: -100), 0)
            XCTAssertEqual(geometry.spinePosition(atY: 5000), 62)
            XCTAssertEqual(geometry.rowOpacity(offset: 0), 1)
            XCTAssertEqual(geometry.rowOpacity(offset: CGFloat(geometry.span) + 1), 0)
        }
        // DESIGN.md §7: rows at pitch 47, the focused row 2 × 92 tall at y 452.
        XCTAssertEqual(LadderGeometry.phone.rowY(offset: -1), 360)
        XCTAssertEqual(LadderGeometry.phone.rowY(offset: 5), 452 + 92 + 4 * 47)
        XCTAssertEqual(LadderGeometry.phone.spineY(1) - LadderGeometry.phone.spineY(0), 614.0 / 62, accuracy: 0.0001)
    }

    // MARK: The lens

    func testLensOfTheHelionAtVectorA() throws {
        let lens = LensReading.read(clock, at: a, level: .helion, zone: nil)
        XCTAssertEqual(lens.ordinalLine, "rung 7 of 63")
        XCTAssertEqual(lens.kindLine, "depth 7 · level 6 · unit")
        // The kind is the core's word for every rung (frc_format_level_kind), never the app's own.
        for level in Level.all {
            XCTAssertTrue(LensReading.read(clock, at: a, level: level, zone: nil).kindLine
                .hasSuffix(" · \(level.kind.text)"), "\(level)")
        }
        XCTAssertEqual(LensReading.read(clock, at: a, level: .alpha, zone: nil).kindLine, "depth 1 · level 0 · major")
        XCTAssertEqual(lens.epithet?.tone, .sun)
        XCTAssertEqual(lens.lineage.map(\.name), ["α", "β", "γ", "δ", "ε", "ζ", "η"])
        XCTAssertEqual(lens.prefixLabel, "Exact P(6)")
        XCTAssertEqual(lens.prefix, ["125\(g)125 = 5 · 13 · 5 · 5 · 7 · 11", "125\(g)125"])
        XCTAssertEqual(lens.travelTitle, "One Helion of travel")

        XCTAssertEqual(lens.rows.map(\.label), ["Made of", "Siblings", "Period", "Rate", "Band"])
        XCTAssertEqual(lens.rows[0].pure, ["36ι · 9 θ", "36ι"])
        XCTAssertEqual(lens.rows[1].pure.first, "11 in ζ · 77 in ε · now 1 of 11")
        XCTAssertEqual(lens.rows[2].pure.first, "36ι · 2\(g)340λ · 58\(g)500ν")
        XCTAssertEqual(lens.rows[3].pure.first, "1 per 58\(g)500 Blinks")
        XCTAssertEqual(lens.rows[4].pure, ["no band"])
        XCTAssertTrue(lens.rows.allSatisfy(\.earth.isEmpty))

        // The four thresholds of the running Helion, signed, from the core's spans.
        let ring = try XCTUnwrap(lens.ring)
        XCTAssertEqual(ring.thresholds.map(\.quarter), [.peak, .node, .valley, .end])
        XCTAssertEqual(ring.thresholds.map(\.span), ["−20ι 21λ", "−11ι 21λ", "−2ι 21λ", "+6ι 43λ"])
        XCTAssertEqual(ring.thresholds.map(\.isNext), [false, false, false, true])
        // The glyph states of SPEC §4 at the quarters: 4, 8, 12 and 0.
        XCTAssertEqual(ring.thresholds.map { $0.glyph?.index }, [4, 8, 12, 0])
        XCTAssertTrue(ring.thresholds.allSatisfy { $0.earth == nil })
        XCTAssertEqual(ring.instrument.live?.odometer.digits, [13, 0])
        XCTAssertEqual(ring.instrument.beadsLit, 8)

        // The seven media as spans of light (design/README.md ruling 2).
        XCTAssertEqual(lens.media.map(\.span), ["1η", "24ι 1λ", "3.5ν", "2.05ξ", "5.15ο", "1.80ο", "6.15χ"])
        XCTAssertTrue(lens.media.allSatisfy { $0.word == "light" && $0.earth == nil })
        XCTAssertEqual(lens.media.first?.place, 1)
        XCTAssertEqual(lens.media.map(\.place), lens.media.map(\.place).sorted(by: >))
    }

    func testLensEarthTranslation() throws {
        let lens = LensReading.read(clock, at: a, level: .helion, zone: utc)
        let ring = try XCTUnwrap(lens.ring)
        XCTAssertEqual(ring.thresholds.map(\.earth), ["09:08:51", "10:24:38", "11:40:25", "12:56:12"])
        XCTAssertEqual(lens.rows[2].earth, ["5.052 h"])
        XCTAssertEqual(lens.rows[3].earth, ["54.98 µHz"])
        XCTAssertEqual(lens.media.map(\.earth), ["5.453 Tm", "3.638 Tm", "327.4 Mm", "27.28 Mm", "6.239 Mm", "2.183 Mm", "18.19 m"])
        // The Fractonica values are still there: Earth is set beside them.
        XCTAssertEqual(lens.rows[2].pure.first, "36ι · 2\(g)340λ · 58\(g)500ν")

        // Under the Blink: the band's edges and a device that makes the rung.
        let xi = LensReading.read(clock, at: a, level: try XCTUnwrap(Level(13)), zone: utc)
        XCTAssertEqual(xi.rows.map(\.label), ["Made of", "Siblings", "Period", "Rate", "Band", "Device"])
        XCTAssertEqual(xi.rows[2].pure, ["0.14ν"])
        XCTAssertEqual(xi.rows[4].earth, ["20 Hz – 20 kHz"])
        XCTAssertEqual(xi.rows[5].pure, [])
        XCTAssertEqual(xi.rows[5].earth.last, "44\(g)417 ticks at 1 MHz")
        let zeta1 = LensReading.read(clock, at: a, level: try XCTUnwrap(Level(29)), zone: utc)
        XCTAssertEqual(zeta1.epithet?.tone, .visibleLight)
        XCTAssertEqual(zeta1.rows.map(\.label), ["Made of", "Siblings", "Rate", "Band"])
        XCTAssertEqual(zeta1.rows[2].earth.first, "2.189 fs · 456.8 THz")
        XCTAssertEqual(zeta1.rows[3].earth, ["400 THz – 790 THz"])
    }

    func testLensOfEveryRung() throws {
        let outside = Instant(unixSeconds: 40_000_000_000)!
        for level in Level.all {
            let lens = LensReading.read(clock, at: a, level: level, zone: nil)
            XCTAssertEqual(lens.lineage.count, level.depth)
            XCTAssertEqual(lens.media.count, 7)
            XCTAssertFalse(lens.rows.isEmpty)
            XCTAssertFalse(lens.prefix.isEmpty)
            // A live ring for the levels the instrument can show, and no other.
            XCTAssertEqual(lens.ring != nil, AppModel.focusRange.contains(level.index), "\(level)")
            if let ring = lens.ring {
                XCTAssertNotNil(ring.instrument.live)
                XCTAssertTrue(ring.thresholds.allSatisfy { $0.span != nil && $0.glyph != nil })
                XCTAssertEqual(ring.thresholds.filter(\.isNext).count, 1)
            }
            // Outside the catalogue the ring is engraved: no spans, nothing running.
            let engraved = LensReading.read(clock, at: outside, level: level, zone: nil)
            XCTAssertNil(engraved.ring?.instrument.live)
            XCTAssertTrue(engraved.ring?.thresholds.allSatisfy { $0.span == nil && !$0.isNext } ?? true)
            XCTAssertFalse(engraved.rows.contains { row in row.pure.contains { $0.contains("now") } })
        }
        XCTAssertEqual(LensReading.read(clock, at: a, level: .alpha, zone: nil).rows[1].pure, ["now 6 of 18"])
    }

    // MARK: Pure mode

    /// Fragments that only an Earth translation would contain, and a number
    /// followed by an Earth unit.
    private let earthly = [":", "UTC", "GMT", "OCT", "2026", "Earth", "⊕", "%", "Hz", "ticks"]
    private let earthUnit = #"[0-9] ?(s|ms|min|h|d|y|m|nm|µm|mm|km|Mm|Gm|Tm|Pm|Hz)\b"#

    func testPureLadderAndLensCarryNoEarthText() throws {
        var texts: [String] = []
        for rung in LadderReading.read(clock, at: a, earth: false).rungs {
            texts += [LadderSpeech.label(rung), LadderSpeech.value(rung), rung.caption, rung.sizeWordings.joined(separator: " "),
                      rung.rate, rung.rateRounded, rung.madeOf ?? "", rung.length ?? ""]
        }
        for level in Level.all {
            let lens = LensReading.read(clock, at: a, level: level, zone: nil)
            texts += [LensSpeech.title(lens), LensSpeech.lineage(lens), LensSpeech.media(lens),
                      lens.travelTitle, lens.prefixLabel] + lens.prefix
            texts += lens.rows.flatMap { [$0.label, LensSpeech.row($0)] + $0.pure + $0.earth }
            texts += lens.media.flatMap { [$0.name, $0.span, $0.word, $0.earth ?? ""] }
            if let ring = lens.ring {
                texts.append(LensSpeech.ring(ring, outOfCatalogue: ""))
                texts += ring.thresholds.flatMap { [$0.span ?? "", $0.earth ?? ""] }
            }
        }
        XCTAssertGreaterThan(texts.count, 2000)
        for text in texts {
            for fragment in earthly {
                XCTAssertFalse(text.contains(fragment), "\"\(text)\" contains \"\(fragment)\"")
            }
            XCTAssertNil(text.range(of: earthUnit, options: .regularExpression), "\"\(text)\"")
        }
    }

    func testSpeech() throws {
        let rung = RungReading.read(try XCTUnwrap(Level(29)), interval: LadderReading.interval(clock, at: a), earth: true)
        XCTAssertEqual(LadderSpeech.label(rung), "Rung 30 of 63")
        XCTAssertEqual(
            LadderSpeech.value(rung),
            "Zeta1, sub-Blink, visible, 7 in ε1, made of 11 η1, 142\(g)033\(g)641\(g)750\(g)000 pB, Earth 2.189 fs, 456.8 THz, 656.3 nm"
        )
        let lens = LensReading.read(clock, at: a, level: .helion, zone: utc)
        XCTAssertEqual(LensSpeech.title(lens),
                       "Eta, Helion, rung 7 of 63, depth 7 · level 6 · unit, the unit that locks to the Sun")
        XCTAssertTrue(LensSpeech.ring(try XCTUnwrap(lens.ring), outOfCatalogue: "").hasSuffix("next End +6ι 43λ, Earth 12:56:12"))
        XCTAssertEqual(LensSpeech.row(lens.rows[3]), "1 per 58\(g)500 Blinks, Earth 54.98 µHz")
    }

    // MARK: The model

    @MainActor
    func testRungOfInterest() throws {
        var arguments = LaunchArguments(["x", "--t", "1791460800", "--rung", "29", "--screen", "ladder"])
        XCTAssertEqual(arguments.rung?.index, 29)
        XCTAssertNil(LaunchArguments(["x", "--rung", "63"]).rung)
        arguments.layout = .phone
        let model = AppModel(arguments: arguments)
        XCTAssertEqual(model.lensLevel.index, 29)
        XCTAssertEqual(model.focus, .helion)

        // Turning the ladder moves the rung of interest, never the focus.
        model.step(by: 1)
        XCTAssertEqual(model.lensLevel.index, 30)
        model.step(by: 100)
        XCTAssertEqual(model.lensLevel.index, 62)
        model.inspect(.preon)
        XCTAssertEqual(model.lensLevel, .preon)
        XCTAssertEqual(model.focus, .helion)
        XCTAssertEqual(model.movingLevel, .helion)

        // The lens opens on it; its limb takes the focus along where it can.
        model.openLens(on: model.lensLevel)
        XCTAssertEqual(model.screen, .lens)
        XCTAssertEqual(model.focus, .helion)
        XCTAssertEqual(model.movingLevel, .preon)
        model.step(by: 1)
        XCTAssertEqual(model.lensLevel.index, 9)
        XCTAssertEqual(model.focus.index, 9)
        model.setLensLevel(try XCTUnwrap(Level(40)))
        XCTAssertEqual(model.lensLevel.index, 40)
        XCTAssertEqual(model.focus.index, 9)
        XCTAssertEqual(model.movingLevel.index, 9)

        // Closing the lens returns to where it was opened from.
        model.closeLens()
        XCTAssertEqual(model.screen, .ladder)
        model.closeLens()
        XCTAssertEqual(model.screen, .ladder)
        model.screen = .now
        model.openLens()
        XCTAssertEqual(model.lensLevel.index, 9)
        model.closeLens()
        XCTAssertEqual(model.screen, .now)
        // On NOW the arrow keys still turn the instrument's limb.
        model.step(by: -1)
        XCTAssertEqual(model.focus.index, 8)
    }
}
