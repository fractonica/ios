import SwiftUI
import FractonicaKit

/// The root of the app: fits the design into the window, shows the current
/// screen, and lays the shared chrome over it.
///
/// It is the one place that measures the screen: it builds a ``DesignSpace``
/// from its size and puts it, and the theme, in the environment. Screens are
/// cross-faded over 240 ms (DESIGN.md §10).
struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var hasKeyboard: Bool

    var body: some View {
        GeometryReader { proxy in
            let space = DesignSpace(viewSize: proxy.size, layout: model.forcedLayout, safeArea: proxy.safeAreaInsets)
            ZStack {
                screen
                    .id(model.screen)
                    .transition(.opacity)
                NavigationChrome()
                ReturnMark()
            }
            .environment(\.designSpace, space)
            .animation(Motion.screen.animation(reduceMotion: reduceMotion), value: model.screen)
            .onChange(of: space.layout, initial: true) { _, layout in
                model.layout = layout
            }
        }
        .environment(\.theme, model.theme)
        .background(model.theme.palette.void)
        .ignoresSafeArea()
        // The arrow keys turn the limb (DESIGN.md §8).
        .focusable()
        .focusEffectDisabled()
        .focused($hasKeyboard)
        // On the ladder they turn the wheel (↑ ↓ too), on the lens its limb.
        // On the wave ↑ ↓ step the selected tumbler of the stamp (↑: the
        // value above) and ⌥← ⌥→ select the tumbler beside it.
        .onKeyPress(keys: [.leftArrow, .rightArrow]) { press in
            let steps = press.key == .leftArrow ? -1 : 1
            if model.screen == .wave, press.modifiers.contains(.option) {
                model.selectStampField(by: steps)
                return .handled
            }
            return step(steps)
        }
        .onKeyPress(.upArrow) { vertical(-1) }
        .onKeyPress(.downArrow) { vertical(1) }
        // Return opens the lens on the ladder's rung; Escape leaves the lens.
        .onKeyPress(.return) {
            guard model.screen == .ladder else { return .ignored }
            model.openLens(on: model.lensLevel)
            return .handled
        }
        .onKeyPress(.escape) {
            guard model.screen == .lens else { return .ignored }
            model.closeLens()
            return .handled
        }
        .onAppear { hasKeyboard = true }
        // When a text field gives the keyboard back, the keys are ours again.
        .onChange(of: model.isTyping) { _, typing in
            if !typing { hasKeyboard = true }
        }
        #if os(iOS)
        // The system status bar is hidden in both modes: in pure mode it
        // would show a clock time, and in Earth mode the device's real time
        // above an instrument that may show another moment (the Earth date
        // line already carries the civil time of the moment shown).
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        #endif
    }

    private func step(_ steps: Int) -> KeyPress.Result {
        model.step(by: steps)
        return .handled
    }

    private func vertical(_ steps: Int) -> KeyPress.Result {
        if model.screen == .wave {
            model.stepStamp(by: steps)
        } else {
            model.step(by: steps)
        }
        return .handled
    }

    @ViewBuilder
    private var screen: some View {
        switch model.screen {
        case .now: NowScreen()
        case .ladder: LadderScreen()
        case .lens: LensScreen()
        case .wave: WaveScreen()
        }
    }
}
