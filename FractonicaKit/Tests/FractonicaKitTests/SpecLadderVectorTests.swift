import FractonicaKit
import XCTest

/// SPEC.md §16.5 typed in literally, plus the tables of §16.2 and §16.3.
final class SpecLadderVectorTests: XCTestCase {
    private let blink = Level.blink // level 12, ν
    private let xi = Level(13)!
    private let zeta1 = Level(29)! // depth 30
    private let omicron2 = Level(62)!

    /// A double must agree with an exact fraction to the last bits.
    private func assertClose(
        _ value: Double, _ numerator: Double, _ denominator: Double,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        let expected = numerator / denominator
        XCTAssertEqual(value, expected, accuracy: abs(expected) * 1e-14, file: file, line: line)
    }

    func testReferenceInterval() {
        // "In the reference interval, I = 568,972,877,000 ms"
        XCTAssertEqual(SarosInterval.reference.numerator, 568_972_877_000)
        XCTAssertEqual(SarosInterval.reference.denominator, 1)
    }

    func testPeriodsAndFrequencies() throws {
        // T(12), the Blink: 51724807/166359375 s = 310.922 ms
        assertClose(blink.periodSeconds(), 51_724_807, 166_359_375)
        assertClose(try blink.period().value, 51_724_807, 166_359_375)
        XCTAssertEqual(blink.periodText(digits: 6), "310.922 ms")
        XCTAssertEqual(try blink.period().text(.time, digits: 6), "310.922 ms")

        // f(13), ξ: 1164515625/51724807 Hz = 22.5137 Hz
        assertClose(xi.frequencyHertz(), 1_164_515_625, 51_724_807)
        assertClose(try xi.frequency().value, 1_164_515_625, 51_724_807)
        XCTAssertEqual(xi.frequencyText(digits: 6), "22.5137 Hz")

        // f(62), ο2: 107008321717714395645982788862060546875000000000000/51724807 Hz = 2.0688 × 10⁴² Hz
        assertClose(omicron2.frequencyHertz(), 1.07008321717714395645982788862060546875e50, 51_724_807)
        XCTAssertEqual(omicron2.frequencyText(digits: 5), "2.0688 × 10⁴² Hz")
        XCTAssertEqual(omicron2.name, "ο2")

        // The 17 exact digits of T(12): 0.31092208058758…
        let period = try blink.period()
        XCTAssertTrue((10_000_000_000_000_000 ..< 100_000_000_000_000_000).contains(period.mantissa))
        XCTAssertEqual(period.exponent, -17)
    }

    func testLengths() throws {
        // length(12), light in vacuum: 2215243861443658/23765625 m = 93,212.1 km
        assertClose(blink.lengthMetres(), 2_215_243_861_443_658, 23_765_625)
        assertClose(try blink.length().value, 2_215_243_861_443_658, 23_765_625)
        XCTAssertEqual(blink.lengthText(digits: 6), "93.2121 Mm")
        XCTAssertEqual(blink.lengthText(), "93.21 Mm")

        // length(12, air): 2534515543/23765625 m = 106.646 m
        assertClose(blink.lengthMetres(speed: Medium.air.speed), 2_534_515_543, 23_765_625)
        XCTAssertEqual(blink.lengthText(speed: Medium.air.speed, digits: 6), "106.646 m")

        // length(12, nerve): 413798456/11090625 m = 37.3107 m
        assertClose(blink.lengthMetres(speed: Medium.nerve.speed), 413_798_456, 11_090_625)
        XCTAssertEqual(blink.lengthText(speed: Medium.nerve.speed, digits: 6), "37.3107 m")

        // length(12, chemical): 51724807/166359375000 m = 310.922 µm
        assertClose(blink.lengthMetres(speed: Medium.chemical.speed), 51_724_807, 166_359_375_000)
        XCTAssertEqual(blink.lengthText(speed: Medium.chemical.speed, digits: 6), "310.922 µm")

        // length(29), ζ1, light in vacuum: 1107621930721829/1687759133607421875000 m = 656.268 nm
        assertClose(zeta1.lengthMetres(), 1_107_621_930_721_829, 1.687759133607421875e21)
        XCTAssertEqual(zeta1.lengthText(digits: 6), "656.268 nm")
        XCTAssertEqual(zeta1.name, "ζ1")
        XCTAssertEqual(zeta1.depth, 30)
    }

    func testMeanInterval() throws {
        // "On the mean interval of Saros 141, 39,259,007,522,784 / 69 ms:
        //  f(12) = 250529296875/77894856196 Hz, which is 3.21625 Hz, and T(12) is 310.921 ms"
        let mean = clock.meanInterval
        XCTAssertEqual(mean.numerator, 39_259_007_522_784)
        XCTAssertEqual(mean.denominator, 69)
        assertClose(blink.frequencyHertz(mean), 250_529_296_875, 77_894_856_196)
        XCTAssertEqual(blink.frequencyText(mean, digits: 6), "3.21625 Hz")
        XCTAssertEqual(blink.periodText(mean, digits: 6), "310.921 ms")

        // The interval that holds A is the 2010 – 2028 one: the reference.
        let held = try clock.interval(at: Vector.a)
        XCTAssertEqual(blink.periodText(held, digits: 6), "310.922 ms")
        assertClose(blink.periodSeconds(held), 51_724_807, 166_359_375)
    }

    func testSection16_3Media() {
        XCTAssertEqual(Medium.allCases.map(\.id), [
            "vacuum", "bounded", "diamond", "water", "air", "nerve", "chemical",
        ])
        XCTAssertEqual(Medium.allCases.map(\.name), [
            "Light in vacuum", "Light in bounded medium", "Diamond sound", "Water sound", "Air sound",
            "Nerve conduction", "Chemical transport",
        ])
        XCTAssertEqual(Medium.allCases.map(\.phase), [
            "Vacuum", "Vacuum + solid", "Solid", "Liquid", "Gas", "Solid + liquid", "Liquid + gas + solid",
        ])
        XCTAssertEqual(Medium.vacuum.speed, Speed(numerator: 299_792_458))
        XCTAssertEqual(Medium.bounded.speed, Speed(numerator: 200_000_000))
        XCTAssertEqual(Medium.air.speed, Speed(numerator: 343))
        XCTAssertEqual(Medium.chemical.speed, Speed(numerator: 1, denominator: 1000))
        XCTAssertEqual(Speed.light, Medium.vacuum.speed)
    }

    func testSection16_2Bands() throws {
        // "Depth 30 (ζ1) is red light, 656.3 nm."
        XCTAssertEqual(zeta1.band(), .visible)
        XCTAssertEqual(zeta1.lengthText(), "656.3 nm")
        // The Blink is 3.2 Hz: below 20 Hz, no band. ξ is 22.5 Hz: audible.
        XCTAssertEqual(blink.band(), .noBand)
        XCTAssertEqual(xi.band(), .audible)
        XCTAssertEqual(Band.allCases.map(\.name), [
            // The core said "—" for no band until it took design ruling 4's words.
            "no band", "audible", "radio", "microwave", "infrared", "visible", "ultraviolet", "X-ray", "gamma ray",
        ])
        // Going down the ladder the bands never go back.
        let order = Band.allCases
        var last = 0
        var seen = Set<Band>()
        for level in Level.all {
            let band = level.band()
            seen.insert(band)
            guard band != .noBand else { continue }
            let rank = try XCTUnwrap(order.firstIndex(of: band))
            XCTAssertGreaterThanOrEqual(rank, last, "\(level)")
            last = rank
        }
        XCTAssertEqual(seen, Set(Band.allCases))
    }

    func testSection16_4Devices() throws {
        // One Blink on a 1 MHz timer: round(T(12) × 10⁶) = round(310922.08…) ticks.
        XCTAssertEqual(try blink.deviceTicks(rate: 1_000_000), 310_922)
        // ξ (22.5 Hz) on a 48 kHz, 32-bit oscillator: round(f × 2³² / 48000).
        let step = try xi.deviceStep(rate: 48000, bits: 32)
        XCTAssertEqual(Double(step), (1_164_515_625.0 / 51_724_807.0) * 4_294_967_296.0 / 48000.0, accuracy: 0.5)
        // "A period of less than half a tick cannot be counted. A frequency
        //  above half the sample rate cannot be made": refused, not rounded.
        XCTAssertThrows(.refused, try zeta1.deviceTicks(rate: 1_000_000))
        XCTAssertThrows(.refused, try zeta1.deviceStep(rate: 48000, bits: 32))
        XCTAssertThrows(.invalidArgument, try blink.deviceTicks(rate: 0))
        XCTAssertThrows(.invalidArgument, try blink.deviceStep(rate: 48000, bits: 65))
    }

    func testZeroIntervalIsRefused() {
        let zero = SarosInterval(numerator: 0)
        XCTAssertThrows(.invalidArgument, try blink.period(zero))
        XCTAssertThrows(.invalidArgument, try blink.frequency(zero))
        XCTAssertThrows(.invalidArgument, try blink.length(zero))
        XCTAssertEqual(blink.periodText(zero), "")
        XCTAssertEqual(blink.periodSeconds(zero), 0)
        XCTAssertEqual(blink.band(zero), .noBand)
    }

    func testAlphaInterval() {
        // interval = alpha / 4: an Alpha of four reference intervals is the reference scale.
        let nominal = SarosInterval(alphaMilliseconds: 4 * 568_972_877_000)
        XCTAssertEqual(blink.periodText(nominal, digits: 6), "310.922 ms")
    }

    func testCallerQuantityIsWrittenByTheCore() throws {
        // A value of the caller's own goes through frc_format_quantity: the
        // edges of SPEC §16.2 and a device's rate.
        XCTAssertEqual(try XCTUnwrap(Quantity(digits: 4, exponent: 14)).text(.frequency, digits: 3), "400 THz")
        XCTAssertEqual(try XCTUnwrap(Quantity(digits: 79, exponent: 13)).text(.frequency, digits: 3), "790 THz")
        XCTAssertEqual(try XCTUnwrap(Quantity(digits: 48, exponent: 3)).text(.frequency, digits: 2), "48 kHz")
        XCTAssertEqual(try XCTUnwrap(Quantity(digits: 1, exponent: 6)).text(.frequency, digits: 1), "1 MHz")
        XCTAssertEqual(try XCTUnwrap(Quantity(digits: 4, exponent: 14)).value, 4e14, accuracy: 1)
        XCTAssertNil(Quantity(digits: 0, exponent: 0))
    }
}
