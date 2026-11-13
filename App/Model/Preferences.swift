import Foundation
import FractonicaKit

/// What survives a relaunch: the mode and the focus level (UserDefaults).
/// A launch that pins state (``LaunchArguments/pinsState``) gets an
/// ``ephemeral`` store that reads the defaults and writes nothing.
struct Preferences: Sendable {
    private let writes: Bool
    private static let modeKey = "mode"
    private static let focusKey = "focus"

    /// Reads and writes the user's defaults.
    static let standard = Preferences(writes: true)
    /// Reads the user's defaults, never writes: for pinned launches and snapshots.
    static let ephemeral = Preferences(writes: false)

    var mode: DisplayMode {
        UserDefaults.standard.string(forKey: Preferences.modeKey).flatMap(DisplayMode.init(rawValue:)) ?? .pure
    }

    /// The Helion until the user turns the limb.
    var focus: Level {
        guard UserDefaults.standard.object(forKey: Preferences.focusKey) != nil,
              let level = Level(UserDefaults.standard.integer(forKey: Preferences.focusKey))
        else { return .helion }
        return AppModel.focusable(level)
    }

    func save(mode: DisplayMode) {
        guard writes else { return }
        UserDefaults.standard.set(mode.rawValue, forKey: Preferences.modeKey)
    }

    func save(focus: Level) {
        guard writes else { return }
        UserDefaults.standard.set(focus.index, forKey: Preferences.focusKey)
    }
}
