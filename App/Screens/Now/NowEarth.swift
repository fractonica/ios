import Foundation
import FractonicaKit

/// The Earth translations of the NOW screen (DESIGN.md §9), made from the
/// instants of a ``NowReading``.
///
/// EARTH MODE ONLY: built only while the mode is Earth (or fading out of it).
/// Every string comes from `EarthText` (the core's Earth forms), the drift
/// in seconds from `ShimCoreGaps.seconds`.
struct NowEarth: Equatable, Sendable {
    /// `THU 8 OCT 2026  ·  12:00:00 UTC`, under the reading.
    var dateLine = ""
    /// Under each countdown: when the threshold falls (`12:56:12` on the day
    /// shown, `9 OCT 01:34` or `3 FEB 2028` further away), and the duration
    /// until it (`56 min 12 s`).
    var countdownTimes: [String] = []
    var countdownDurations: [String] = []
    /// Under the Sun's values: the sync's start, the drift in seconds, the
    /// time of its next quarter.
    var syncStart = ""
    var driftSeconds = ""
    var syncNext = ""
    /// When each upcoming threshold falls, in the order of `Live.upcoming`.
    var upcoming: [String] = []

    static func read(_ reading: NowReading, at instant: Instant, zone: TimeZone) -> NowEarth {
        var earth = NowEarth()
        guard let live = reading.live else { return earth }
        earth.dateLine = EarthText.dateLine(instant, zone: zone)
        for countdown in live.countdowns {
            let at = countdown.threshold.instant
            // A time of day alone only when the threshold is on the day shown.
            earth.countdownTimes.append(at.map { EarthText.when($0, from: instant, zone: zone) } ?? "")
            earth.countdownDurations.append(at.map { EarthText.duration(from: instant, to: $0) } ?? "")
        }
        if let sun = live.sun {
            earth.syncStart = EarthText.dayClock(sun.sync.start, zone: zone, seconds: false)
            earth.driftSeconds = ShimCoreGaps.seconds(microseconds: sun.sync.driftMicroseconds)
            earth.syncNext = sun.sync.next.instant.map { EarthText.dayClock($0, zone: zone, seconds: true) } ?? ""
        }
        earth.upcoming = live.upcoming.map { row in
            row.threshold.instant.map { EarthText.when($0, from: instant, zone: zone) } ?? ""
        }
        return earth
    }
}
