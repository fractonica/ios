import FractonicaKit
import XCTest

/// Levels and units against the tables of SPEC §3.1, §3.4, §15.1 and §16.4.
final class HierarchyTests: XCTestCase {
    func testLevels() {
        XCTAssertEqual(Level.count, 63)
        XCTAssertEqual(Level.all.count, 63)
        XCTAssertEqual(Level.all.map(\.index), Array(0 ... 62))
        XCTAssertEqual(Level.clockMax.index, 21)
        XCTAssertEqual(Level.clockLevels.count, 22)
        XCTAssertNil(Level(-1))
        XCTAssertNil(Level(63))
        XCTAssertEqual(Level(6), .helion)
        XCTAssertEqual(Level.helion.depth, 7) // "depth 7" is level 6 (pitfall 6)
        XCTAssertEqual(Level.all.filter(\.isClockLevel).map(\.index), Array(0 ... 21))
        XCTAssertNil(Level.alpha.parent)
        XCTAssertEqual(Level.helion.parent?.index, 5)
        XCTAssertEqual(Level.helion.child?.index, 7)
        XCTAssertNil(Level(62)?.child)
        XCTAssertEqual(Level.helion.offset(by: -6), .alpha)
        XCTAssertNil(Level.helion.offset(by: 57))
        XCTAssertLessThan(Level.alpha, Level.blink)
    }

    func testFactorsAndPrefixes() throws {
        // S = [5, 13, 5, 5, 7, 11, 9, 4], repeating; siblings(L) = S[(L − 1) mod 8].
        let sequence = [5, 13, 5, 5, 7, 11, 9, 4]
        for level in Level.all {
            XCTAssertEqual(level.factor, sequence[level.index % 8], "\(level)")
            XCTAssertEqual(level.siblings, level.index == 0 ? 0 : sequence[(level.index - 1) % 8], "\(level)")
            XCTAssertEqual(level.siblings, level.parent?.factor ?? 0)
        }
        // P(L), from the list of §16.4.
        XCTAssertEqual(Level.alpha.prefix, 1)
        XCTAssertEqual(Level.helion.prefix, 125_125)
        XCTAssertEqual(Level.blink.prefix, 7_319_812_500)
        XCTAssertEqual(Level(21)?.prefix, 230_804_667_843_750_000)
        XCTAssertEqual(Level(22)?.prefix, 2_538_851_346_281_250_000)
        XCTAssertNil(try XCTUnwrap(Level(23)).prefix) // does not fit 64 bits
        XCTAssertEqual(Level.helion.prefixText, "125125")
        XCTAssertEqual(Level(23)?.prefixText, "22849662116531250000")
        XCTAssertEqual(Level(62)?.prefixText, "4708366155579433408423242709930664062500000000000000")
        // Each prefix is the previous one times the factor, where both fit.
        for level in Level.all.prefix(22) {
            XCTAssertEqual(try XCTUnwrap(level.child?.prefix), try XCTUnwrap(level.prefix) * UInt64(level.factor))
        }
    }

    func testNames() {
        // §3.4: α … ω, then α1 … ο2.
        XCTAssertEqual(Level.all.prefix(24).map(\.name).joined(), "αβγδεζηθικλμνξοπρστυφχψω")
        XCTAssertEqual(Level(24)?.name, "α1")
        XCTAssertEqual(Level(29)?.name, "ζ1")
        XCTAssertEqual(Level(48)?.name, "α2")
        XCTAssertEqual(Level(62)?.name, "ο2")
        XCTAssertEqual(Level.all.prefix(13).map(\.word), [
            "Alpha", "Beta", "Gamma", "Delta", "Epsilon", "Zeta", "Eta", "Theta", "Iota", "Kappa", "Lambda",
            "Mu", "Nu",
        ])
        XCTAssertEqual(Level(23)?.word, "Omega")
        XCTAssertEqual(Level(24)?.word, "Alpha1")
        XCTAssertEqual(Set(Level.all.map(\.name)).count, 63, "every rung has its own name")
    }

    func testKinds() {
        XCTAssertEqual(Level.all.prefix(14).map(\.kind), [
            .major, .major, .major, .major, // α β γ δ
            .unit, .between, .unit, .between, .unit, .between, .unit, .between, .unit, // ε ζ η θ ι κ λ μ ν
            .subBlink, // ξ
        ])
        XCTAssertTrue(Level.all.dropFirst(13).allSatisfy { $0.kind == .subBlink })
    }

    func testUnitsOfSection15_1() {
        XCTAssertEqual(Unit.allCases.count, 9)
        XCTAssertEqual(Unit.allCases.map(\.symbol), ["α", "β", "γ", "δ", "ε", "η", "ι", "λ", "ν"])
        XCTAssertEqual(Unit.allCases.map(\.name), [
            "Alpha", "Beta", "Gamma", "Delta", "Nuclide", "Helion", "Preon", "Flavon", "Blink",
        ])
        XCTAssertEqual(Unit.helion.name(plural: true), "Helions")
        // Depths 1 2 3 4 5 7 9 11 13.
        XCTAssertEqual(Unit.allCases.map(\.level.depth), [1, 2, 3, 4, 5, 7, 9, 11, 13])
        // "Made of": 5 Beta, 13 Gamma, 5 Delta, 5 Nuclide, 77 Helion, 36 Preon, 65 Flavon, 25 Blink.
        XCTAssertEqual(Unit.allCases.map(\.parts), [5, 13, 5, 5, 77, 36, 65, 25, 0])
        XCTAssertEqual(Unit.blink.blinks, 1)
        XCTAssertEqual(Unit.flavon.blinks, 25)
        XCTAssertEqual(Unit.preon.blinks, 1625)
        XCTAssertEqual(Unit.helion.blinks, 58500)
        XCTAssertEqual(Unit.nuclide.blinks, 4_504_500)
        XCTAssertEqual(Unit.alpha.blinks, 7_319_812_500)
        for unit in Unit.allCases {
            XCTAssertEqual(unit.level.unit, unit)
            if let finer = unit.finer {
                XCTAssertEqual(unit.blinks, finer.blinks * UInt64(unit.parts))
                XCTAssertEqual(finer.coarser, unit)
                XCTAssertLessThan(unit, finer)
            }
        }
        XCTAssertNil(Unit.blink.finer)
        XCTAssertNil(Unit.alpha.coarser)
        XCTAssertEqual(Level.all.compactMap(\.unit), Unit.allCases)
        XCTAssertEqual(Level.nuclide.index, 4)
        XCTAssertEqual(Level.preon.index, 8)
        XCTAssertEqual(Level.flavon.index, 10)
        XCTAssertEqual(Level.blink.index, 12)
    }
}
