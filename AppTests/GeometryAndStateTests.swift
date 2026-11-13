import XCTest
import FractonicaKit
@testable import Fractonica

/// Where the rings are, what a launch pins, and the rules of the model.
final class GeometryAndStateTests: XCTestCase {
    func testPhoneRingRadiiOfTheDesign() throws {
        // DESIGN.md §5: ζ 139.7, ☉ 149.2, ε 160.3, δ 166.8, γ 173.3, β 179.8, α 186.3.
        let geometry = InstrumentGeometry(metrics: .phone, focus: .helion)
        let expected: [(Int, CGFloat)] = [(5, 139.7), (4, 160.3), (3, 166.8), (2, 173.3), (1, 179.8), (0, 186.3)]
        for (level, radius) in expected {
            XCTAssertEqual(try XCTUnwrap(geometry.ringRadii[level]), radius, accuracy: 0.06, "level \(level)")
        }
        XCTAssertEqual(try XCTUnwrap(geometry.sunRadius), 149.2, accuracy: 0.06)
        XCTAssertEqual(geometry.outerRadius, 186.3, accuracy: 0.06)
        XCTAssertEqual(geometry.ring(atRadius: 161)?.index, 4)
        XCTAssertNil(geometry.ring(atRadius: 80))
    }

    func testRingsAlwaysFit() throws {
        for metrics in [InstrumentMetrics.phone, .desktop] {
            for index in AppModel.focusRange {
                let geometry = InstrumentGeometry(metrics: metrics, focus: try XCTUnwrap(Level(index)))
                XCTAssertLessThanOrEqual(geometry.outerRadius, metrics.maxOuterRadius + 0.01, "focus \(index)")
                XCTAssertEqual(geometry.ringRadii.count, index)
                XCTAssertEqual(geometry.sunRadius != nil, index >= 6)
            }
        }
    }

    func testNestIsBuiltForEveryFocus() throws {
        let clock = Catalogue.saros141
        let a = Instant(unixSeconds: 1_791_460_800)!
        for metrics in [InstrumentMetrics.phone, .desktop] {
            for index in AppModel.focusRange {
                let level = try XCTUnwrap(Level(index))
                let reading = InstrumentReading.read(clock, at: a, focus: level, depth: metrics.nestDepth)
                let geometry = InstrumentGeometry(metrics: metrics, focus: level)
                let carrier = Arc.fullCircle(center: metrics.center, radius: geometry.heroRadius)
                let nest = NestRenderer.build(carrier: carrier, focus: level, running: reading.live?.nested, depth: metrics.nestDepth)
                XCTAssertGreaterThanOrEqual(nest.layers.count, 1, "focus \(index)")
                let point = try XCTUnwrap(nest.nowPoint, "focus \(index)")
                // The point of now is on the hero's arcs: between the bezel
                // and the first counter ring.
                let distance = hypot(point.x - metrics.center.x, point.y - metrics.center.y)
                XCTAssertGreaterThan(distance, geometry.bezelRadius, "focus \(index)")
                XCTAssertLessThan(distance, geometry.firstRingRadius, "focus \(index)")
                // Engraved: no point of now, nothing on the lit paths.
                let engraved = NestRenderer.build(carrier: carrier, focus: level, running: nil, depth: metrics.nestDepth)
                XCTAssertNil(engraved.nowPoint)
                XCTAssertTrue(engraved.layers.allSatisfy { $0.elapsed.isEmpty && $0.pathElapsed.isEmpty })
            }
        }
    }

    /// The hero's arcs, with everything nested on them, never reach the
    /// counter rings: a level of few children moves the first ring out, and
    /// where there is no room for that the hero ring itself is smaller.
    func testHeroStaysInsideTheCounterRings() throws {
        for metrics in [InstrumentMetrics.phone, .desktop] {
            for index in AppModel.focusRange {
                let level = try XCTUnwrap(Level(index))
                let geometry = InstrumentGeometry(metrics: metrics, focus: level)
                XCTAssertLessThanOrEqual(geometry.heroRadius, metrics.radius, "focus \(index)")
                XCTAssertGreaterThan(geometry.heroRadius, metrics.radius * 0.85, "focus \(index)")
                let carrier = Arc.fullCircle(center: metrics.center, radius: geometry.heroRadius)
                let nest = NestRenderer.build(carrier: carrier, focus: level, running: nil, depth: metrics.nestDepth)
                for layer in nest.layers {
                    // A bounding box touches the arcs' furthest points along
                    // the axes; turned through a quarter in small steps it
                    // finds the furthest point in every direction.
                    for degrees in stride(from: 0.0, to: 90.0, by: 3.0) {
                        var turn = CGAffineTransform(translationX: metrics.center.x, y: metrics.center.y)
                            .rotated(by: degrees * .pi / 180)
                            .translatedBy(x: -metrics.center.x, y: -metrics.center.y)
                        let box = try XCTUnwrap(layer.toCome.copy(using: &turn)).boundingBoxOfPath
                        let reach = max(metrics.center.x - box.minX, box.maxX - metrics.center.x,
                                        metrics.center.y - box.minY, box.maxY - metrics.center.y)
                        XCTAssertLessThan(reach, geometry.firstRingRadius, "focus \(index) at \(degrees)°")
                    }
                }
                XCTAssertLessThan(geometry.bezelRadius, geometry.heroRadius, "focus \(index)")
            }
        }
        // The Helion is as designed: R 102, the first ring at 1.37 R.
        let helion = InstrumentGeometry(metrics: .phone, focus: .helion)
        XCTAssertEqual(helion.heroRadius, 102)
        XCTAssertEqual(helion.firstRingRadius, 139.74, accuracy: 0.01)
        XCTAssertEqual(helion.bezelRadius, 72.42, accuracy: 0.01)
    }

    func testLaunchArguments() throws {
        let arguments = LaunchArguments([
            "Fractonica", "--t", "1791460800", "--mode", "earth", "--screen", "lens", "--focus", "9",
            "--theme", "basalt", "--layout", "desktop", "--zone", "UTC", "-NSDocumentRevisionsDebugMode", "YES",
        ])
        XCTAssertEqual(arguments.frozenInstant, Instant(unixSeconds: 1_791_460_800))
        XCTAssertEqual(arguments.mode, .earth)
        XCTAssertEqual(arguments.screen, .lens)
        XCTAssertEqual(arguments.focus?.index, 9)
        XCTAssertEqual(arguments.themeName, "basalt")
        XCTAssertEqual(arguments.layout, .desktop)
        XCTAssertEqual(arguments.timeZone?.secondsFromGMT(), 0)
        XCTAssertTrue(arguments.pinsState)
        XCTAssertFalse(LaunchArguments(["Fractonica"]).pinsState)
        // A focus beyond the focusable levels is brought back to them.
        XCTAssertEqual(LaunchArguments(["x", "--focus", "40"]).focus?.index, 13)
        XCTAssertEqual(Theme.named("basalt").name, "basalt")
        XCTAssertEqual(Theme.named(nil).name, "astrolabe")
    }

    @MainActor
    func testModelRules() throws {
        var arguments = LaunchArguments()
        arguments.frozenInstant = Instant(unixSeconds: 1_791_460_800)
        let model = AppModel(arguments: arguments)
        XCTAssertTrue(model.isTimeFrozen)
        XCTAssertTrue(model.isAtNow)
        XCTAssertEqual(model.focus, .helion)
        model.stepFocus(by: 20)
        XCTAssertEqual(model.focus.index, 13)
        model.stepFocus(by: -40)
        XCTAssertEqual(model.focus, .alpha)
        // Time travel clamps to the catalogue.
        model.scrub(to: Instant(unixSeconds: 40_000_000_000)!)
        XCTAssertEqual(model.cursor, model.clock.last)
        XCTAssertFalse(model.isAtNow)
        model.returnToNow()
        XCTAssertEqual(model.instant, arguments.frozenInstant)
        model.openLens(on: Level(29))
        XCTAssertEqual(model.screen, .lens)
        XCTAssertEqual(model.lensLevel.index, 29)
        XCTAssertEqual(model.focus, .alpha)
    }

    func testScheduleIsBounded() throws {
        let clock = Catalogue.saros141
        let a = Instant(unixSeconds: 1_791_460_800)!
        let next = try XCTUnwrap(ClockSchedule.nextChange(in: clock, after: a, focus: .helion, nestDepth: 2))
        XCTAssertGreaterThan(next, a)
        // A Blink is about a third of a second: something changes within one.
        XCTAssertLessThan(next.microseconds(since: a), 400_000)
        XCTAssertEqual(ClockSchedule.delay(from: a, until: a.advanced(byMicroseconds: 10)), ClockSchedule.minimumInterval)
        XCTAssertEqual(ClockSchedule.delay(from: a, until: nil), ClockSchedule.maximumInterval)
        XCTAssertNil(ClockSchedule.nextChange(in: clock, after: Instant(unixSeconds: 40_000_000_000)!, focus: .helion, nestDepth: 2))
    }
}
