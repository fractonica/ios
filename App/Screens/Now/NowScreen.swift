import SwiftUI
import FractonicaKit

/// NOW: the instrument, the limb under it, and the reading around it
/// (DESIGN.md §7 and §9), in both arrangements and both modes.
///
/// Layers, back to front:
/// 1. `PlateView`: the ground, turned on the instrument's centre.
/// 2. `InstrumentView`: the hero (its own motion, gestures, accessibility).
/// 3. `LimbControl`: the curved limb, bound to the focus.
/// 4. `NowPanel`: the words and numbers (`NowPhoneRenderer` or
///    `NowDesktopRenderer`), with one accessibility element per block.
struct NowScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(\.designSpace) private var space

    var body: some View {
        let metrics = InstrumentMetrics.standard(space.layout)
        ZStack {
            // The machining marks start just outside the limb.
            PlateView(center: metrics.center, firstRadius: space.layout == .desktop ? 371 : 214)
            InstrumentView(metrics: metrics)
            LimbControl(level: model.focusBinding, selectable: AppModel.focusRange, shape: .curved(metrics))
            NowPanel()
        }
        .onScrollWheelStep { model.stepFocus(by: $0) }
    }
}

/// The words and numbers of NOW around the instrument, read at the model's
/// instant and drawn for the arrangement on screen.
private struct NowPanel: View {
    @Environment(AppModel.self) private var model
    @Environment(\.designSpace) private var space
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let instant = model.instant, zone = model.timeZone, layout = space.layout
        let reading = NowReading.read(model.clock, at: instant, focus: model.focus)
        ZStack {
            MotionCanvas(value: model.mode == .earth ? 1.0 : 0.0) { ink, earth in
                // The Earth lines exist only while Earth mode is on screen.
                let lines = earth > 0 ? NowEarth.read(reading, at: instant, zone: zone) : nil
                switch layout {
                case .phone: NowPhoneRenderer.draw(reading, earthLines: lines, earth: earth, in: &ink)
                case .desktop: NowDesktopRenderer.draw(reading, earthLines: lines, earth: earth, in: &ink)
                }
            }
            .animation(Motion.mode.animation(reduceMotion: reduceMotion), value: model.mode)

            spokenElements(reading)
        }
    }

    // MARK: Accessibility

    /// One element per block: the Pentad, the date and reading, each
    /// countdown, the Sun. In pure mode no Earth line is built or spoken.
    private func spokenElements(_ reading: NowReading) -> some View {
        let earth = model.mode == .earth ? NowEarth.read(reading, at: model.instant, zone: model.timeZone) : nil
        let zone: TimeZone? = model.mode == .earth ? model.timeZone : nil
        let frames = NowSpokenFrames(layout: space.layout, earth: model.mode == .earth)
        let countdowns = Array((reading.live?.countdowns ?? []).prefix(2).enumerated())
        return ZStack {
            Color.clear
                .accessibilityElement()
                .accessibilityLabel("Pentad")
                .accessibilityValue(reading.pentad?.text(.full, withHelion: true) ?? reading.outOfCatalogue)
                .designFrame(frames.pentad)
            Color.clear
                .accessibilityElement()
                .accessibilityLabel("Date")
                .accessibilityIdentifier("now.date")
                .accessibilityValue(spokenDate(reading, earth: earth))
                .designFrame(frames.date)
            ForEach(countdowns, id: \.offset) { index, countdown in
                Color.clear
                    .accessibilityElement()
                    .accessibilityLabel("\(countdown.level.unit?.name ?? countdown.level.word), \(countdown.threshold.quarter.name) in")
                    .accessibilityValue(spokenCountdown(countdown, earth: earth, index: index))
                    .designFrame(frames.countdowns[index])
            }
            Color.clear
                .accessibilityElement()
                .accessibilityLabel("Sun")
                .accessibilityValue(spokenSun(reading, earth: earth, zone: zone))
                .designFrame(frames.sun)
        }
        .allowsHitTesting(false)
    }

    private func spokenDate(_ reading: NowReading, earth: NowEarth?) -> String {
        guard let live = reading.live else { return reading.outOfCatalogue }
        var text = live.date.text(.full)
        if let earth { text += ", Earth \(earth.dateLine)" }
        return text
    }

    private func spokenCountdown(_ countdown: NowReading.Countdown, earth: NowEarth?, index: Int) -> String {
        var text = "\(countdown.span), \(countdown.cycle.placeText)"
        if let earth, index < earth.countdownTimes.count {
            text += ", Earth \(earth.countdownTimes[index]), \(earth.countdownDurations[index])"
        }
        return text
    }

    private func spokenSun(_ reading: NowReading, earth: NowEarth?, zone: TimeZone?) -> String {
        var text = InstrumentSpeech.sunValue(reading, zone: zone)
        if let drift = reading.live?.sun?.drift { text += ", drift \(drift)" }
        if let earth, !earth.driftSeconds.isEmpty { text += ", Earth \(earth.driftSeconds)" }
        return text
    }
}

/// Where the blocks of the NOW panel are, for the accessibility elements
/// (design coordinates; the same blocks the renderers draw).
private struct NowSpokenFrames {
    let pentad: CGRect
    let date: CGRect
    let countdowns: [CGRect]
    let sun: CGRect

    init(layout: LayoutClass, earth: Bool) {
        switch layout {
        case .phone:
            let shift: CGFloat = earth ? 6 : 0
            pentad = CGRect(x: 18, y: 68, width: 130, height: 28)
            date = CGRect(x: 20, y: 520 - shift, width: 353, height: 70 + 2 * shift)
            countdowns = [
                CGRect(x: 30, y: 604 + shift, width: 160, height: 56 + 2 * shift),
                CGRect(x: 203, y: 604 + shift, width: 160, height: 56 + 2 * shift),
            ]
            sun = CGRect(x: 20, y: 684 + shift, width: 353, height: 58)
        case .desktop:
            let shift: CGFloat = earth ? 26 : 0
            let x = NowDesktopRenderer.left, width = NowDesktopRenderer.right - NowDesktopRenderer.left
            pentad = CGRect(x: x, y: 76, width: width, height: 26)
            date = CGRect(x: x, y: 112, width: width, height: 196 + shift)
            countdowns = [
                CGRect(x: x, y: 352 + shift, width: 190, height: 84),
                CGRect(x: x + 196, y: 352 + shift, width: 186, height: 84),
            ]
            sun = CGRect(x: x, y: 468 + shift, width: width, height: 76)
        }
    }
}
