import XCTest

/// Drives the running app as a person would, at SPEC vector A with time
/// frozen: reads NOW, turns the limb, toggles the mode, opens each screen,
/// scrubs the wave and returns to the present.
///
/// The elements are found by accessibility identifier (never shown or
/// spoken); what is asserted is what assistive technology would say, so the
/// test also holds the pure-mode rule on the running app: no Earth text
/// until the mode says EARTH.
///
///     Tools/test-ui.sh            on the iPhone simulator
final class InstrumentTourUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = [
            "--t", "1791460800", "--zone", "UTC", "--mode", "pure", "--screen", "now", "--focus", "6",
        ]
        app.launch()
    }

    func testTourOfTheInstrument() {
        // NOW, pure: the date of vector A and nothing of Earth.
        let date = element("now.date")
        XCTAssertTrue(date.waitForExistence(timeout: 15))
        XCTAssertTrue(spoken(date).contains("Delta Trifracton End"), spoken(date))
        XCTAssertTrue(spoken(date).contains("34η 29ι 21λ 3ν"), spoken(date))
        XCTAssertFalse(spoken(date).contains("2026"), spoken(date))
        XCTAssertEqual(spoken(element("mode")), "Pure")

        // Turn the limb: the focus leaves the Helion.
        let limb = element("limb")
        XCTAssertEqual(spoken(limb), "Eta, Helion")
        drag(limb, by: CGVector(dx: -90, dy: 0))
        XCTAssertTrue(wait { self.spoken(limb) != "Eta, Helion" }, "the limb did not turn: \(spoken(limb))")
        attach("now-limb-turned")

        // Toggle the mode: the Earth translation appears, and goes again.
        element("mode").tap()
        XCTAssertTrue(wait { self.spoken(self.element("mode")) == "Earth" })
        XCTAssertTrue(wait { self.spoken(date).contains("THU 8 OCT 2026") }, spoken(date))
        attach("now-earth")
        element("mode").tap()
        XCTAssertTrue(wait { self.spoken(self.element("mode")) == "Pure" })
        XCTAssertTrue(wait { !self.spoken(date).contains("2026") }, spoken(date))

        // Each screen opens from its sigil.
        for (screen, mark) in [("ladder", "ladder.rung"), ("lens", "lens.title"), ("wave", "wave.moment")] {
            element("sigil.\(screen)").tap()
            XCTAssertTrue(element(mark).waitForExistence(timeout: 5), "\(screen) did not open")
            attach(screen)
        }

        // Scrub the wave: the cursor leaves the present, and NOW returns it.
        let nowMark = element("wave.now")
        XCTAssertEqual(nowMark.label, "Now")
        XCTAssertTrue(spoken(element("wave.moment")).contains("34η 29ι 21λ 3ν"), spoken(element("wave.moment")))
        drag(element("wave.track"), by: CGVector(dx: -120, dy: 0))
        XCTAssertTrue(wait { nowMark.label == "Return to now" }, "the wave did not scrub")
        XCTAssertFalse(spoken(element("wave.moment")).contains("34η 29ι 21λ 3ν"))
        attach("wave-scrubbed")
        nowMark.tap()
        XCTAssertTrue(wait { nowMark.label == "Now" }, "NOW did not return to the present")
        XCTAssertTrue(wait { self.spoken(self.element("wave.moment")).contains("34η 29ι 21λ 3ν") })

        // And back to NOW.
        element("sigil.now").tap()
        XCTAssertTrue(date.waitForExistence(timeout: 5))
        XCTAssertTrue(spoken(date).contains("34η 29ι 21λ 3ν"), spoken(date))
    }

    /// The whole mode control toggles: the word (PURE / EARTH) and the ring
    /// mark beside it (○ / ⊕), and it is at least 44 points each way. (Found
    /// by hand: a tap on the ring did nothing, only the word answered.) The
    /// ring and the word are found where they are drawn, by their place in
    /// the control's frame (ChromePlaces, design points: the phone's frame is
    /// 296...393 × 43...110 on NOW, the ring centred at 363, 82 and its top at 74.5,
    /// the word ending at 348; the desktop's 4...84 × 20...104, the ring at
    /// 44, 56).
    func testTheModeRingToggles() {
        let mode = element("mode")
        XCTAssertTrue(mode.waitForExistence(timeout: 15))
        XCTAssertEqual(spoken(mode), "Pure")
        // At least 44 points each way, the smallest comfortable target.
        XCTAssertGreaterThanOrEqual(mode.frame.width, 44)
        XCTAssertGreaterThanOrEqual(mode.frame.height, 44)
        let isDesktop = app.frame.width >= 700
        let targets: [(String, CGVector)] = isDesktop
            ? [("the ring", CGVector(dx: (44.0 - 4) / 80, dy: (56.0 - 20) / 84)),
               ("the ring's top", CGVector(dx: (44.0 - 4) / 80, dy: (49.0 - 20) / 84)),
               ("the word", CGVector(dx: (44.0 - 4) / 80, dy: (78.0 - 20) / 84))]
            : [("the ring", CGVector(dx: (363.0 - 296) / 97, dy: (82.0 - 43) / 67)),
               ("the ring's top", CGVector(dx: (363.0 - 296) / 97, dy: (75.0 - 43) / 67)),
               ("the ring's right", CGVector(dx: (370.0 - 296) / 97, dy: (82.0 - 43) / 67)),
               ("the word", CGVector(dx: (335.0 - 296) / 97, dy: (82.0 - 43) / 67))]
        var expected = "Pure"
        for (place, offset) in targets {
            mode.coordinate(withNormalizedOffset: offset).tap()
            expected = expected == "Pure" ? "Earth" : "Pure"
            XCTAssertTrue(wait { self.spoken(mode) == expected }, "a tap on \(place) did not toggle the mode")
        }
    }

    /// An iPad on its side takes the desktop arrangement: every screen still
    /// opens and reads vector A. (A phone stays upright; a Mac has no sides.)
    func testEveryScreenOnAnIPadOnItsSide() throws {
        #if os(iOS)
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, "an iPad's arrangement")
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }
        let date = element("now.date")
        XCTAssertTrue(date.waitForExistence(timeout: 15))
        XCTAssertTrue(wait { self.app.frame.width > self.app.frame.height }, "the app did not turn")
        XCTAssertTrue(spoken(date).contains("34η 29ι 21λ 3ν"), spoken(date))
        attach("ipad-landscape-now-pure")
        element("mode").tap()
        XCTAssertTrue(wait { self.spoken(date).contains("THU 8 OCT 2026") }, spoken(date))
        attach("ipad-landscape-now-earth")
        for (screen, mark) in [("ladder", "ladder.rung"), ("lens", "lens.title"), ("wave", "wave.moment")] {
            element("sigil.\(screen)").tap()
            XCTAssertTrue(element(mark).waitForExistence(timeout: 5), "\(screen) did not open")
            attach("ipad-landscape-\(screen)-earth")
        }
        #else
        throw XCTSkip("an iPad's arrangement")
        #endif
    }

    // MARK: Helpers

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    /// What assistive technology says for an element: its value.
    private func spoken(_ element: XCUIElement) -> String {
        element.value as? String ?? ""
    }

    /// A slow drag from the middle of an element, as a finger or a pointer does it.
    private func drag(_ element: XCUIElement, by offset: CGVector) {
        let start = element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.15, thenDragTo: start.withOffset(offset))
    }

    private func wait(_ timeout: TimeInterval = 5, until condition: @escaping () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        return condition()
    }

    /// Keeps a screenshot in the test report.
    private func attach(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
