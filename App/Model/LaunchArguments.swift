import Foundation
import FractonicaKit

/// The launch arguments that pin the app's state for tests, screenshots and
/// snapshots. Everything is optional; with none the app is the live clock.
///
///     --t <unix seconds>     freezes time at that instant (SPEC vector A: 1791460800)
///     --cursor <unix seconds> a scrubbed cursor: the moment shown, away from now (clamped to the catalogue)
///     --mode pure|earth
///     --screen now|ladder|lens|wave
///     --focus <level>        0...13 (level, not depth: the Helion is 6)
///     --rung <level>         0...62: the rung the lens inspects and the ladder is turned to
///     --theme astrolabe|basalt
///     --layout phone|desktop forces the arrangement (otherwise chosen from the view's size)
///     --zone <identifier>    Earth-mode time zone, e.g. UTC or Europe/Paris (default: the device's)
///     --snapshot <directory> renders every screen to PNG files there and exits (App/Snapshot)
///     --icon <directory>     draws the app icon's master pictures there and exits (Tools/icon.sh)
///     --size <W>x<H>         a view size in points: the Mac window opens at it; with --snapshot the
///                            screens are rendered at that size (how the design fits another window)
///
/// When any of them is present nothing is written back to the preferences, so
/// a test launch never changes what the user sees next time.
struct LaunchArguments: Equatable, Sendable {
    var frozenInstant: Instant?
    /// A scrubbed cursor to start with (snapshots of time travel).
    var cursor: Instant?
    var mode: DisplayMode?
    var screen: Screen?
    var focus: Level?
    /// The rung of interest (lens, ladder): any of the 63 levels.
    var rung: Level?
    var themeName: String?
    var layout: LayoutClass?
    var timeZone: TimeZone?
    var snapshotDirectory: String?
    /// A view size of the caller's own, in points: the Mac window opens at
    /// it, and snapshot mode renders the screens at it instead of its set.
    var size: CGSize?
    /// Where to draw the app icon's master pictures (Tools/icon.sh).
    var iconDirectory: String?

    /// No pins: the live clock with the user's preferences.
    static let none = LaunchArguments()

    /// The arguments this process was started with.
    static var current: LaunchArguments { LaunchArguments(ProcessInfo.processInfo.arguments) }

    /// Whether the launch pins anything (then preferences are left alone).
    var pinsState: Bool { self != .none }

    init() {}

    /// Reads `--name value` pairs; unknown names and malformed values are
    /// ignored (Xcode and XCTest pass arguments of their own).
    init(_ arguments: [String]) {
        var index = arguments.startIndex
        while index < arguments.endIndex {
            let name = arguments[index]
            let value: String? = arguments.index(after: index) < arguments.endIndex
                ? arguments[arguments.index(after: index)] : nil
            index = arguments.index(after: index)
            guard name.hasPrefix("--"), let value else { continue }
            switch name {
            case "--t":
                frozenInstant = Int64(value).flatMap(Instant.init(unixSeconds:))
            case "--cursor":
                cursor = Int64(value).flatMap(Instant.init(unixSeconds:))
            case "--mode":
                mode = DisplayMode(rawValue: value.lowercased())
            case "--screen":
                screen = Screen(rawValue: value.lowercased())
            case "--focus":
                focus = Int(value).flatMap(Level.init).map(AppModel.focusable)
            case "--rung":
                rung = Int(value).flatMap(Level.init)
            case "--theme":
                themeName = value.lowercased()
            case "--layout":
                layout = LayoutClass(rawValue: value.lowercased())
            case "--zone":
                timeZone = TimeZone(identifier: value)
            case "--snapshot":
                snapshotDirectory = value
            case "--icon":
                iconDirectory = value
            case "--size":
                let parts = value.lowercased().split(separator: "x").compactMap { Double($0) }
                if parts.count == 2, parts[0] >= 100, parts[1] >= 100 {
                    size = CGSize(width: parts[0], height: parts[1])
                }
            default:
                continue
            }
            index = arguments.index(after: index)
        }
    }
}
