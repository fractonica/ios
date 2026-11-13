import SwiftUI
import FractonicaKit

/// The process entry point. With `--snapshot <directory>` the app renders
/// its pictures and exits without ever showing a window (App/Snapshot), with
/// `--icon <directory>` it draws its own icon the same way; otherwise it
/// runs the SwiftUI app.
@main
enum FractonicaMain {
    @MainActor
    static func main() {
        let arguments = LaunchArguments.current
        TextRendering.useDeviceWeights()
        if let directory = arguments.snapshotDirectory {
            exit(SnapshotRunner.run(arguments, directory: directory))
        }
        if let directory = arguments.iconDirectory {
            exit(IconRenderer.run(arguments, directory: directory))
        }
        FractonicaApp.main()
    }
}

/// The Fractonica clock: one window, one model.
///
/// Nothing a user can reach here names an Earth unit: the window has no
/// title, and the menu speaks of levels, screens and the two modes only.
struct FractonicaApp: App {
    @State private var model = AppModel(arguments: .current)
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .onAppear {
                    model.start()
                    #if os(macOS)
                    // `--size`: a remembered window frame outranks the default
                    // size, so a pinned size is set on the window itself.
                    if let size = LaunchArguments.current.size {
                        DispatchQueue.main.async {
                            NSApp.windows.first { $0.isVisible }?.setContentSize(size)
                        }
                    }
                    #endif
                }
                .onChange(of: scenePhase) { _, phase in
                    // The clock runs only while it can be seen.
                    if phase == .background { model.stop() } else { model.start() }
                }
                #if os(macOS)
                // Narrow enough to tile into half of a laptop's screen: a
                // window narrower than it is wide gets the phone arrangement
                // (`LayoutClass.fitting`).
                .frame(minWidth: 360, minHeight: 560)
                #endif
        }
        #if os(macOS)
        .defaultSize(LaunchArguments.current.size ?? LayoutClass.desktop.designSize)
        .windowStyle(.hiddenTitleBar)
        #endif
        .commands { InstrumentCommands(model: model) }
    }
}

/// The keyboard: ← → turn the limb, ⌘1 – ⌘4 choose a screen, ⌘E switches
/// between pure and Earth, ⌘0 returns to now, ⌘↩ focuses the instrument on
/// the rung the ladder or the lens is turned to.
struct InstrumentCommands: Commands {
    let model: AppModel

    var body: some Commands {
        CommandMenu("Instrument") {
            // While a text field has the keyboard the arrows move its caret.
            Button("Coarser") { model.step(by: -1) }
                .keyboardShortcut(.leftArrow, modifiers: [])
                .disabled(model.isTyping)
            Button("Finer") { model.step(by: 1) }
                .keyboardShortcut(.rightArrow, modifiers: [])
                .disabled(model.isTyping)
            Divider()
            ForEach(Array(Screen.allCases.enumerated()), id: \.offset) { index, screen in
                Button(screen.word.capitalized) { model.screen = screen }
                    .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: .command)
            }
            Divider()
            Button(model.mode == .pure ? "Earth Mode" : "Pure Mode") { model.toggleMode() }
                .keyboardShortcut("e", modifiers: .command)
            Button("Return to Now") { model.returnToNow() }
                .keyboardShortcut("0", modifiers: .command)
                .disabled(model.isAtNow)
            Divider()
            // The ladder's long press, for the keyboard: the instrument
            // focuses on the rung the ladder or the lens is turned to.
            Button("Focus Instrument on Rung") { model.focusOnRung() }
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(model.isTyping || model.screen == .now || model.screen == .wave || !model.canFocusOnRung)
        }
    }
}

/// How the Mac rasterises text.
enum TextRendering {
    /// Turns off the Mac's font smoothing for this process, before anything
    /// is drawn. With it on, macOS thickens the stems of light text on a dark
    /// ground by about a fifth, and the thin engraved type of the design
    /// (drawn for, and matched on, iOS) comes out visibly heavier, on screen
    /// and in snapshots alike. Nothing is persisted: the value lives in the
    /// process's volatile argument domain, as if `-AppleFontSmoothing 0` had
    /// been passed on the command line.
    static func useDeviceWeights() {
        #if os(macOS)
        let defaults = UserDefaults.standard
        var domain = defaults.volatileDomain(forName: UserDefaults.argumentDomain)
        domain["AppleFontSmoothing"] = 0
        defaults.setVolatileDomain(domain, forName: UserDefaults.argumentDomain)
        #endif
    }
}
