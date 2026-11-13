import XCTest
import SwiftUI
import FractonicaKit
@testable import Fractonica

/// What the hands and the window do: the two-finger gesture, the tumblers at
/// the catalogue's edges, the coasting wave, and how the design fits a view.
@MainActor
final class InputAndFitTests: XCTestCase {
    private let a = Instant(unixSeconds: 1_791_460_800)!

    // MARK: Pinch or twist

    func testAPinchIsNotChangedByAStrayTwist() {
        var steps = TwoFingerSteps()
        let ratio = 1.37
        // A pinch that wobbles 4.1° (half a limb step, which used to count as one).
        steps.twist(degrees: 4.1, step: 8.2)
        steps.pinch(magnification: ratio * 1.05, ratio: ratio)
        steps.twist(degrees: 6, step: 8.2)
        XCTAssertEqual(steps.owner, .pinch)
        XCTAssertEqual(steps.steps, 1)
        // Twisting further does not add to a pinch.
        steps.twist(degrees: 30, step: 8.2)
        XCTAssertEqual(steps.steps, 1)
    }

    func testATwistCountsOnlyPastItsThreshold() {
        var steps = TwoFingerSteps()
        steps.twist(degrees: 12, step: 8.2)
        XCTAssertNil(steps.owner)
        XCTAssertEqual(steps.steps, 0)
        steps.twist(degrees: 15, step: 8.2)
        XCTAssertEqual(steps.owner, .twist)
        XCTAssertEqual(steps.steps, 1)
        steps.twist(degrees: 15 + 2 * 8.2, step: 8.2)
        XCTAssertEqual(steps.steps, 3)
        // A pinch that comes after does nothing.
        steps.pinch(magnification: 3, ratio: 1.37)
        XCTAssertEqual(steps.steps, 3)
        // Counter-clockwise: coarser.
        var back = TwoFingerSteps()
        back.twist(degrees: -16, step: 8.2)
        XCTAssertEqual(back.steps, -1)
    }

    // MARK: Tumblers and the coast

    func testARefusedStepSaysSo() throws {
        let model = AppModel(arguments: LaunchArguments(["--t", "1791460800"]))
        model.scrub(to: model.clock.last)
        XCTAssertFalse(model.step(.unit(.helion), by: 1), "beyond the closing instant")
        XCTAssertEqual(model.instant, model.clock.last)
        XCTAssertTrue(model.step(.unit(.helion), by: -1))
        model.scrub(to: model.clock.first)
        XCTAssertFalse(model.step(.unit(.preon), by: -1))
    }

    func testReturningToNowStopsACoast() async throws {
        let model = AppModel(arguments: LaunchArguments(["--t", "1791460800"]))
        model.scrub(to: a.advanced(byMicroseconds: 3_600_000_000))
        model.glide(alongWaveOf: .helion, velocity: 1_000, cycleWidth: 208)
        XCTAssertNotNil(model.coastTask)
        try await Task.sleep(for: .milliseconds(50))
        model.returnToNow()
        XCTAssertNil(model.coastTask)
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertTrue(model.isAtNow, "a frame of the coast scrubbed away from now again")
        // A typed moment is not undone either.
        model.glide(alongWaveOf: .helion, velocity: -1_000, cycleWidth: 208)
        try await Task.sleep(for: .milliseconds(50))
        let typed = a.advanced(byMicroseconds: -86_400_000_000)
        model.scrub(to: typed)
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertEqual(model.instant, typed)
    }

    // MARK: Fitting the design

    func testTheDesignsOwnPhoneIsDrawnAsDesigned() {
        let space = DesignSpace(viewSize: CGSize(width: 393, height: 852), layout: .phone,
                                safeArea: SwiftUI.EdgeInsets(top: 59, leading: 0, bottom: 34, trailing: 0))
        XCTAssertEqual(space.scale, 1)
        XCTAssertEqual(space.origin, CGPoint.zero)
        XCTAssertEqual(space.engravedFloor, 0)
        // A snapshot (no insets) is the same picture.
        XCTAssertEqual(DesignSpace(viewSize: CGSize(width: 393, height: 852), layout: .phone).origin, CGPoint.zero)
    }

    /// A 375 × 667 iPhone SE has neither the Dynamic Island's band nor the
    /// home indicator's: the design's bands are given back, and no engraved
    /// word falls under 6.2 pt.
    func testASmallPhoneGetsItsBandsBack() {
        let space = DesignSpace(viewSize: CGSize(width: 375, height: 667), layout: .phone)
        XCTAssertGreaterThan(space.scale, 0.85, "was 0.78 when the bands were scaled with the design")
        // The content band (59 ... 818) fills the view.
        XCTAssertEqual(space.origin.y + 59 * space.scale, 0, accuracy: 0.5)
        XCTAssertEqual(space.origin.y + 818 * space.scale, 667, accuracy: 0.5)
        XCTAssertEqual(space.engravedFloor * space.scale, DesignSpace.phoneEngravedMinimum, accuracy: 0.001)
        var theme = Theme.astrolabe
        theme.engravedFloor = space.engravedFloor
        // A 5.8 pt label of the design is set at the floor, 6.2 pt on screen.
        XCTAssertEqual(theme.engraved(5.8, theme.palette.ash).tracking, space.engravedFloor * theme.type.engravedTracking,
                       accuracy: 0.001)
    }

    /// The mode toggle is the word AND its ring: one hit frame holds both,
    /// 44 view points or more each way on every phone (on WAVE, where it
    /// must end above the NOW mark, an SE without a status bar keeps 31.6 of
    /// them on screen), and clear of what the screens beneath it take.
    func testTheModeControlHoldsItsWordAndItsRing() {
        for layout in [LayoutClass.phone, .desktop] {
            let places = ChromePlaces(layout: layout)
            for screen in Screen.allCases {
                let frame = places.modeHitFrame(on: screen)
                let ring = CGRect(x: places.mode.x - 7.5, y: places.mode.y - 7.5, width: 15, height: 15)
                XCTAssertTrue(frame.contains(ring.insetBy(dx: -4, dy: -4)), "\(layout) \(screen): the ring and a margin")
                XCTAssertTrue(frame.contains(places.modeLabel), "\(layout) \(screen): the word's anchor")
                XCTAssertLessThanOrEqual(frame.maxX, layout.designSize.width)
                XCTAssertGreaterThanOrEqual(frame.minY, 0)
            }
        }
        let phone = ChromePlaces(layout: .phone)
        // The word ends at its anchor and EARTH is about 30 points wide.
        XCTAssertLessThanOrEqual(phone.modeHitFrame(on: .now).minX, phone.modeLabel.x - 40)
        XCTAssertLessThanOrEqual(phone.modeHitFrame(on: .wave).maxY, WaveLayout.phone.nowMarkFrame.minY)
        XCTAssertFalse(ChromePlaces(layout: .desktop).modeHitFrame(on: .wave).intersects(WaveLayout.desktop.nowMarkFrame))
        // Clear of the instrument's touch disc on NOW (its reach is the outer radius + 8).
        let metrics = InstrumentMetrics.phone
        let frame = phone.modeHitFrame(on: .now)
        let corner = CGPoint(x: frame.minX, y: frame.maxY)
        XCTAssertGreaterThanOrEqual(hypot(corner.x - metrics.center.x, corner.y - metrics.center.y),
                                    metrics.maxOuterRadius + 8)
        XCTAssertLessThanOrEqual(frame.maxY, LensLayout.phone.swipeFrame.minY)

        let views: [(CGSize, EdgeInsets)] = [
            (CGSize(width: 375, height: 667), EdgeInsets(top: 20, leading: 0, bottom: 0, trailing: 0)),
            (CGSize(width: 375, height: 667), EdgeInsets()),
            (CGSize(width: 393, height: 852), EdgeInsets(top: 59, leading: 0, bottom: 34, trailing: 0)),
            (CGSize(width: 375, height: 812), EdgeInsets(top: 50, leading: 0, bottom: 34, trailing: 0)),
        ]
        for (size, safeArea) in views {
            let space = DesignSpace(viewSize: size, layout: .phone, safeArea: safeArea)
            for screen in Screen.allCases {
                // The part of the frame on the screen.
                let onScreen = space.viewRect(phone.modeHitFrame(on: screen))
                    .intersection(CGRect(origin: .zero, size: size))
                XCTAssertGreaterThanOrEqual(onScreen.width, 44, "\(size) \(screen)")
                if screen == .wave {
                    XCTAssertGreaterThanOrEqual(onScreen.height, 31, "\(size) \(screen)")
                } else {
                    XCTAssertGreaterThanOrEqual(onScreen.height, 44, "\(size) \(screen)")
                }
            }
        }
        // The desktop arrangement on an upright iPad (mini, 11-inch, 13-inch)
        // and a small Mac window.
        let desktop = ChromePlaces(layout: .desktop)
        for size in [CGSize(width: 744, height: 1133), CGSize(width: 820, height: 1180),
                     CGSize(width: 1024, height: 1366), CGSize(width: 960, height: 600)] {
            let space = DesignSpace(viewSize: size, layout: .desktop)
            let frame = space.viewRect(desktop.modeHitFrame(on: .now))
            XCTAssertGreaterThanOrEqual(min(frame.width, frame.height), 44, "\(size)")
            XCTAssertLessThan(desktop.modeHitFrame(on: .now).maxY, desktop.hitFrame(of: .now).minY)
        }
    }

    func testArrangementsForWindowsAndIPads() {
        #if os(macOS)
        XCTAssertEqual(LayoutClass.fitting(CGSize(width: 1280, height: 800)), .desktop)
        XCTAssertEqual(LayoutClass.fitting(CGSize(width: 960, height: 600)), .desktop)
        // Half of a 1470 pt laptop screen: a column, the phone arrangement.
        XCTAssertEqual(LayoutClass.fitting(CGSize(width: 735, height: 920)), .phone)
        #else
        XCTAssertEqual(LayoutClass.fitting(CGSize(width: 1024, height: 1366)), .desktop)
        XCTAssertEqual(LayoutClass.fitting(CGSize(width: 393, height: 852)), .phone)
        XCTAssertEqual(LayoutClass.fitting(CGSize(width: 320, height: 1024)), .phone)
        #endif
    }
}
