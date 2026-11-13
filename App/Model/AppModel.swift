import Foundation
import Observation
import FractonicaKit

/// The app's one piece of shared state: which moment is shown, how, and where.
///
/// Views read it from the environment (`@Environment(AppModel.self)`) and
/// build their own readings from ``clock`` and ``instant`` (see
/// `Model/Readings/`). The model holds no reading itself, so a view is redrawn
/// only when something it actually reads changes.
///
/// - **Time**: ``now`` is advanced by a scheduler that sleeps until the next
///   visible change (``ClockSchedule``); `--t` freezes it.
/// - **Cursor**: `nil` is the present; otherwise a scrubbed instant that every
///   screen shows until ``returnToNow()``. Always inside the catalogue. The
///   ways of moving it are in `AppModel+TimeTravel.swift`.
/// - **Mode**, **focus** (levels 0...13) and **screen**; mode and focus persist.
@MainActor
@Observable
final class AppModel {
    /// The clock every client runs on (design/README.md ruling 8).
    let clock = Catalogue.saros141
    let theme: Theme

    /// The device clock as last sampled by the scheduler (or the frozen instant).
    private(set) var now: Instant
    /// A scrubbed instant, or `nil` for the present. Global to all screens.
    private(set) var cursor: Instant?
    private(set) var mode: DisplayMode
    /// The level the instrument is focused on: 0...13 (ruling 9).
    private(set) var focus: Level
    /// The rung of interest: the one the lens inspects and the ladder's wheel
    /// is turned to. Any of the 63. Follows the focus until the ladder or the
    /// lens points it elsewhere.
    private(set) var lensLevel: Level
    var screen: Screen {
        didSet {
            // Remember where the lens was opened from: closing it goes back there.
            if screen == .lens, oldValue != .lens { lensOrigin = oldValue }
        }
    }
    /// The screen ``closeLens()`` returns to: the last one shown before the lens.
    private(set) var lensOrigin: Screen = .now
    /// The arrangement on screen, mirrored here by `RootView` for logic that
    /// depends on it (the scheduler's nesting depth). Views take it from
    /// `@Environment(\.designSpace)`.
    var layout: LayoutClass
    /// Earth mode's zone: the device's (ruling 6), or the `--zone` pin.
    private(set) var timeZone: TimeZone
    /// The term of the moment the WAVE screen's keys step: the tumbler last
    /// touched. `nil` is the default one (see ``activeStampField``).
    var stampField: StampField?
    /// Whether a text field has the keyboard (the WAVE screen's "go to").
    /// The arrow keys then belong to the text, not to the instrument.
    var isTyping = false

    /// Whether `--t` froze time (tests, screenshots, snapshots).
    let isTimeFrozen: Bool
    /// A layout forced by `--layout` or by the snapshot runner.
    let forcedLayout: LayoutClass?
    private let followsDeviceZone: Bool
    private let preferences: Preferences
    private var ticker: Task<Void, Never>?
    /// The wave coasting after a flick (`glide(alongWaveOf:…)`), owned here
    /// so that every other way of moving through time can stop it.
    @ObservationIgnored var coastTask: Task<Void, Never>?

    /// The levels the instrument can focus on.
    nonisolated static let focusRange: ClosedRange<Int> = 0 ... 13

    /// `level` brought into ``focusRange``.
    nonisolated static func focusable(_ level: Level) -> Level {
        Level(min(max(level.index, focusRange.lowerBound), focusRange.upperBound)) ?? .helion
    }

    init(arguments: LaunchArguments = .none) {
        let preferences: Preferences = arguments.pinsState ? .ephemeral : .standard
        self.preferences = preferences
        theme = Theme.named(arguments.themeName)
        isTimeFrozen = arguments.frozenInstant != nil
        now = arguments.frozenInstant ?? .now
        cursor = arguments.cursor.map(clock.clamped)
        mode = arguments.mode ?? preferences.mode
        let focus = arguments.focus ?? preferences.focus
        self.focus = focus
        lensLevel = arguments.rung ?? focus
        screen = arguments.screen ?? .now
        forcedLayout = arguments.layout
        layout = arguments.layout ?? .phone
        followsDeviceZone = arguments.timeZone == nil
        timeZone = arguments.timeZone ?? .current
    }

    // MARK: The moment shown

    /// The moment every screen shows: the cursor if there is one, else now.
    var instant: Instant { cursor ?? now }
    /// Whether the present is shown (no scrubbed cursor).
    var isAtNow: Bool { cursor == nil }
    /// Whether the clock is defined at the moment shown.
    var isInCatalogue: Bool { clock.contains(instant) }

    /// Moves the cursor; time travel clamps to the catalogue (ruling 7).
    /// Any move but the coasting wave's own frames stops that coast (see
    /// `AppModel+TimeTravel.swift`), so a tap on NOW, a typed moment or a
    /// tumbler is not undone by the frame after it.
    func scrub(to instant: Instant) {
        stopGlide()
        cursor = clock.clamped(instant)
    }

    /// Drops the cursor: every screen shows the present again.
    func returnToNow() {
        stopGlide()
        cursor = nil
    }

    /// Moves the cursor without stopping a coast: the coast's own frames.
    func moveCursorWhileGliding(to instant: Instant) {
        cursor = clock.clamped(instant)
    }

    /// Stops the wave coasting after a flick, if it is.
    func stopGlide() {
        coastTask?.cancel()
        coastTask = nil
    }

    // MARK: Mode, focus, screen

    func setMode(_ mode: DisplayMode) {
        guard mode != self.mode else { return }
        self.mode = mode
        preferences.save(mode: mode)
        // Earth mode shows seconds: wake the scheduler now, not after its
        // current sleep, so they turn on time from the first one.
        if ticker != nil {
            stop()
            start()
        }
    }

    func toggleMode() {
        setMode(mode.toggled)
    }

    /// Focuses the instrument on `level` (clamped to ``focusRange``). The
    /// lens follows.
    func setFocus(_ level: Level) {
        let level = AppModel.focusable(level)
        lensLevel = level
        guard level != focus else { return }
        focus = level
        preferences.save(focus: level)
    }

    /// One step finer (+1) or coarser (−1): the arrow keys, the scroll wheel.
    func stepFocus(by steps: Int) {
        setFocus(focus.offset(by: steps) ?? (steps > 0 ? Level.all[Level.count - 1] : .alpha))
    }

    /// Opens the lens on `level` (any rung), or on the focus.
    func openLens(on level: Level? = nil) {
        lensLevel = level ?? focus
        screen = .lens
    }

    /// Points the lens at a rung without leaving the current screen. The
    /// instrument's focus follows while the rung is one it can show (the
    /// lens's limb: "the same control and the same state", DESIGN.md §8).
    func setLensLevel(_ level: Level) {
        lensLevel = level
        if AppModel.focusRange.contains(level.index) { setFocus(level) }
    }

    /// Turns the ladder to a rung: the rung of interest changes, the
    /// instrument's focus does not (a long press on the ladder does that).
    func inspect(_ level: Level) {
        lensLevel = level
    }

    /// Whether the rung of interest is one the instrument can focus on.
    var canFocusOnRung: Bool { AppModel.focusRange.contains(lensLevel.index) }

    /// Focuses the instrument on the rung of interest (the ladder's long
    /// press, the menu's ⌘↩). Does nothing for a rung finer than the
    /// instrument reads.
    func focusOnRung() {
        guard canFocusOnRung else { return }
        setFocus(lensLevel)
    }

    /// Leaves the lens for the screen it was opened from (swipe down, Escape).
    func closeLens() {
        guard screen == .lens else { return }
        screen = lensOrigin
    }

    /// One step finer (+1) or coarser (−1) on whatever the screen in front
    /// scales by: the ladder's wheel, the lens's limb (all 63 rungs), else
    /// the instrument's focus. The arrow keys, the menu.
    func step(by steps: Int) {
        let last = Level.all[Level.count - 1]
        let target = lensLevel.offset(by: steps) ?? (steps > 0 ? last : .alpha)
        switch screen {
        case .ladder: inspect(target)
        case .lens: setLensLevel(target)
        case .now, .wave: stepFocus(by: steps)
        }
    }

    /// The level whose ring is moving on screen: the lens's own rung while
    /// the lens shows a live ring, else the focus. The scheduler paces the
    /// redraws by it.
    var movingLevel: Level {
        screen == .lens && AppModel.focusRange.contains(lensLevel.index) ? lensLevel : focus
    }

    // MARK: The scheduler

    /// Starts advancing ``now``. Does nothing when time is frozen.
    func start() {
        guard !isTimeFrozen, ticker == nil else { return }
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let delay = self.tick()
                try? await Task.sleep(for: delay)
            }
        }
    }

    /// Stops advancing ``now`` (the app left the foreground).
    func stop() {
        ticker?.cancel()
        ticker = nil
    }

    /// Samples the device clock and returns how long to sleep until the next
    /// visible change.
    private func tick() -> Duration {
        let sampled = Instant.now
        now = sampled
        if followsDeviceZone, timeZone != TimeZone.current { timeZone = .current }
        let next = ClockSchedule.nextChange(
            in: clock, after: sampled, focus: movingLevel, nestDepth: InstrumentMetrics.standard(layout).nestDepth,
            earth: mode == .earth, cursor: cursor
        )
        return ClockSchedule.delay(from: sampled, until: next)
    }
}
