import SwiftUI

/// The navigation every screen shares (DESIGN.md §8): the four sigils
/// (bottom centre on the phone, the left rail on the desktop) and the mode
/// toggle (top right on the phone, top of the rail on the desktop). Drawn
/// with the instrument's own line: no bar, no background, no badge.
struct NavigationChrome: View {
    @Environment(AppModel.self) private var model
    @Environment(\.designSpace) private var space
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let places = ChromePlaces(layout: space.layout)
        let active = model.screen
        ZStack {
            MotionCanvas(value: model.mode == .earth ? 1.0 : 0.0) { ink, earth in
                NavigationChrome.draw(places: places, active: active, earth: earth, in: &ink)
            }
            .animation(Motion.mode.animation(reduceMotion: reduceMotion), value: model.mode)

            ForEach(Screen.allCases, id: \.self) { screen in
                Button { model.screen = screen } label: { Color.clear.contentShape(Rectangle()) }
                    .buttonStyle(.plain)
                    .accessibilityLabel(screen.word.capitalized)
                    .accessibilityIdentifier("sigil.\(screen.rawValue)")
                    .accessibilityAddTraits(screen == active ? .isSelected : [])
                    // The Mac's hover hint (before `.designFrame`, like accessibility).
                    .help(screen.hint)
                    .designFrame(places.hitFrame(of: screen))
            }
            // The toggle says the mode it is in; pure and Earth are the only words.
            Button { model.toggleMode() } label: { Color.clear.contentShape(Rectangle()) }
                .buttonStyle(.plain)
                .accessibilityLabel("Mode")
                .accessibilityIdentifier("mode")
                .accessibilityValue(model.mode.word.capitalized)
                .help("\(model.mode.word.capitalized) mode: switch to \(model.mode.toggled.word.capitalized) (⌘E)")
                .designFrame(places.modeHitFrame(on: active))
        }
    }

    private static func draw(places: ChromePlaces, active: Screen, earth: Double, in ink: inout Ink) {
        let palette = ink.palette, theme = ink.theme
        for screen in Screen.allCases {
            let center = places.sigil(of: screen)
            let isActive = screen == active
            SigilRenderer.draw(screen, center: center, color: isActive ? palette.lumen : palette.etch3, in: &ink)
            ink.text(screen.word, at: CGPoint(x: center.x, y: center.y + places.nameOffset),
                     theme.engraved(6.5, isActive ? palette.ash : palette.etch3), anchor: .middle)
        }
        if let rule = places.railRule {
            ink.line(from: rule.0, to: rule.1, palette.etch1, width: 1)
        }
        Marks.modeSign(center: places.mode, earth: earth, in: &ink)
        // PURE fades out as EARTH fades in: same place, 200 ms.
        for (mode, opacity) in [(DisplayMode.pure, 1 - earth), (DisplayMode.earth, earth)] {
            let lit = mode == .earth && places.modeLabelLitInEarth
            ink.text(mode.word, at: places.modeLabel, theme.engraved(places.modeLabelSize, lit ? palette.ash : palette.etch3),
                     anchor: places.modeLabelAnchor, opacity: opacity)
        }
    }
}

/// Where the chrome sits in each arrangement (design coordinates).
struct ChromePlaces {
    let layout: LayoutClass

    /// Centre of a screen's sigil.
    func sigil(of screen: Screen) -> CGPoint {
        let index = CGFloat(Screen.allCases.firstIndex(of: screen) ?? 0)
        switch layout {
        case .phone: return CGPoint(x: 196.5 + (index - 1.5) * 70, y: 784)
        case .desktop: return CGPoint(x: 44, y: 400 + (index - 1.5) * 74)
        }
    }

    /// The sigil's name sits this far under its centre.
    var nameOffset: CGFloat { layout == .desktop ? 24 : 22 }

    func hitFrame(of screen: Screen) -> CGRect {
        let center = sigil(of: screen)
        switch layout {
        case .phone: return CGRect(x: center.x - 33, y: center.y - 22, width: 66, height: 56)
        case .desktop: return CGRect(x: center.x - 38, y: center.y - 22, width: 76, height: 58)
        }
    }

    /// Centre of the mode toggle's ring.
    var mode: CGPoint {
        layout == .desktop ? CGPoint(x: 44, y: 56) : CGPoint(x: 363, y: 82)
    }

    var modeLabel: CGPoint {
        layout == .desktop ? CGPoint(x: 44, y: 80) : CGPoint(x: 348, y: 84.8)
    }

    var modeLabelAnchor: TextAnchor { layout == .desktop ? .middle : .end }
    var modeLabelSize: CGFloat { layout == .desktop ? 6.5 : 7.5 }
    /// On the phone the word EARTH is ash; in the rail both words are engraved.
    var modeLabelLitInEarth: Bool { layout == .phone }

    /// The whole control, word AND ring, answers a tap: on the phone from
    /// left of the word (which ends at 348) to the design's right edge, past
    /// the ring (radius 7.5 at 363, 82), and at least 44 view points tall
    /// on every phone, Apple's smallest comfortable target. It was a
    /// 33-point band, 296...386 × 62...95, and a tap on the ring was
    /// reported to do nothing.
    ///
    /// It reaches up into the empty safe band (from 43) and down to 110,
    /// where the instrument's touch disc on NOW (centre 196.5, 277, reach
    /// 194) begins at x 296 and LENS's swipe area begins: 44.8 view points on
    /// an iPhone SE that has given its bands back (drawn at 0.88, its top
    /// band off the screen). On WAVE it ends at 95, above the caption row
    /// and its NOW mark: there an SE has 31.6 points of it on the screen,
    /// against the screen's top edge. On the desktop the rail's frame holds
    /// both, 80 × 84 design points: 44 view points and more on an upright
    /// iPad mini, where the desktop design is drawn at 0.58 (it was 76 × 58,
    /// 37 points tall on an upright iPad).
    func modeHitFrame(on screen: Screen) -> CGRect {
        switch layout {
        case .desktop: return CGRect(x: 4, y: 20, width: 80, height: 84)
        case .phone: return CGRect(x: 296, y: 43, width: 97, height: (screen == .wave ? 95 : 110) - 43)
        }
    }

    /// The hairline that closes the left rail.
    var railRule: (CGPoint, CGPoint)? {
        layout == .desktop ? (CGPoint(x: 88, y: 40), CGPoint(x: 88, y: 760)) : nil
    }

    /// Where the NOW return mark is centred while the cursor is away.
    var returnMark: CGPoint {
        layout == .desktop ? CGPoint(x: 452, y: 46) : CGPoint(x: 196.5, y: 74)
    }
}
