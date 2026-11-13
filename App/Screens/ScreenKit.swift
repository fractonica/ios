import SwiftUI
import FractonicaKit

// ============================================================================
// THE CONTRACT OF A SCREEN — read this before adding a screen.
// LADDER (Screens/Ladder), LENS (Screens/Lens) and WAVE (Screens/Wave) are
// worked examples of it.
//
// A screen is a SwiftUI view in `Screens/<Name>/<Name>Screen.swift` that
// `RootView` shows full-screen under the shared chrome (sigils, mode toggle,
// NOW return mark: do not draw those). It takes no arguments.
//
// What it receives, from the environment:
//
//   @Environment(AppModel.self) var model
//       model.clock            Catalogue.saros141: ask it everything
//       model.instant          the moment to show (the cursor, else now)
//       model.now / .cursor / .isAtNow / .isInCatalogue
//       model.scrub(to:)       move the cursor (clamps to the catalogue); .returnToNow()
//                              (more ways to move it: Model/AppModel+TimeTravel.swift)
//       model.mode             .pure / .earth      (.setMode, .toggleMode)
//       model.focus            the instrument's level, 0...13   (.setFocus, .stepFocus(by:), .focusBinding)
//       model.lensLevel        the rung the lens inspects, 0...62 (.openLens(on:), .setLensLevel, .lensLevelBinding)
//       model.screen           set it to navigate
//       model.timeZone         Earth mode's zone
//   @Environment(\.designSpace) var space     space.layout (.phone / .desktop), scale, designPoint(_:)
//   @Environment(\.theme) var theme           the token table (inside a canvas: ink.theme, ink.palette)
//   @Environment(\.accessibilityReduceMotion) pass to Motion.<kind>.animation(reduceMotion:)
//
// How it draws: in DESIGN coordinates (393 × 852 phone, 1280 × 800 desktop),
// on canvases stacked in a ZStack that fills the screen:
//
//   ZStack {
//       PlateView(center: …, firstRadius: …)          the ground (first layer)
//       DesignCanvas { ink in … }                      a still drawing
//       MotionCanvas(value: x) { ink, x in … }         a drawing that follows an animated value
//       LimbControl(level:selectable:shape:)           the limb, curved or straight
//       Button { … } label: { Color.clear.contentShape(Rectangle()) }
//           .buttonStyle(.plain).accessibilityLabel(…)
//           .designFrame(rect)                         a hit area / accessibility element
//   }
//
// Drawing primitives (App/Drawing): Ink (stroke, fill, line, circle, text,
// line of pieces, layer), NestRenderer, GlyphRenderer, CounterRingRenderer,
// SealRenderer, LimbRenderer, SigilRenderer, PlateRenderer, Marks.
// The whole instrument at any size: InstrumentRenderer.draw(reading,
// geometry: InstrumentGeometry(metrics: .inspector(center:radius:), focus:)).
//
// Rules: every number and name comes from the kit (build a small `…Reading`
// struct from `model.clock` at `model.instant`, like `NowReading`); no colour
// or font outside the theme; in pure mode build no Earth text at all;
// accessibility modifiers go BEFORE `.designFrame`.
//
// A screen is part of the snapshots automatically (App/Snapshot renders every
// `Screen` case): Tools/snapshot.sh writes <screen>-<layout>-<mode>.png.
// ============================================================================

/// What a new screen shows until its engineer fills it (none today): the
/// plate, the screen's name, the seal of the level in question and the stamp
/// of the moment shown, with the straight limb where the design puts it.
/// Everything on it is live, so the plumbing (model, theme, design space,
/// snapshots) is already proven for the screen that replaces it.
struct PlaceholderScreen: View {
    let title: String
    let note: String
    /// The level whose seal is shown.
    let level: Level
    /// Where the straight limb sits on the phone (`nil`: no limb).
    let limbBaseline: CGFloat?

    @Environment(AppModel.self) private var model
    @Environment(\.designSpace) private var space

    var body: some View {
        let phone = space.layout == .phone
        // Phone: the design's own column. Desktop: the middle of the area
        // right of the rail (the desktop arrangements of these screens are
        // not designed yet).
        let centre = phone ? CGPoint(x: 196.5, y: 300) : CGPoint(x: 684, y: 340)
        let limb = phone ? limbBaseline.map { CGPoint(x: 196.5, y: $0) } : limbBaseline.map { _ in CGPoint(x: 684, y: 640) }
        let stamp = (try? model.clock.date(at: model.instant).stamp) ?? NowReading.read(model.clock, at: model.instant, focus: model.focus).outOfCatalogue
        let title = title, note = note, level = level
        ZStack {
            PlateView(center: centre, firstRadius: 120)
            DesignCanvas { ink in
                let palette = ink.palette, theme = ink.theme
                let left: CGFloat = phone ? 20 : 132
                ink.text(title, at: CGPoint(x: left, y: 85), theme.engraved(8.5, palette.ash))
                ink.text(note, at: CGPoint(x: left, y: 99), theme.engraved(6.5, palette.etch3))
                SealRenderer.draw(level, center: centre, extent: 60, color: palette.lumen, width: 1.2,
                                  glow: theme.glow.arc, in: &ink)
                ink.text(level.name, at: CGPoint(x: centre.x, y: centre.y + 110), theme.letter(36, palette.bone, weight: .thin), anchor: .middle)
                ink.text(stamp, at: CGPoint(x: centre.x, y: centre.y + 150), theme.value(15), anchor: .middle)
            }
            if let limb {
                LimbControl(level: model.focusBinding, selectable: AppModel.focusRange, shape: .straight(center: limb))
            }
        }
        .onScrollWheelStep { model.stepFocus(by: $0) }
    }
}
