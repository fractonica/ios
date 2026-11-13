import Foundation
import FractonicaKit

/// The Earth translations of the WAVE screen (DESIGN.md §9, "Timeline"),
/// made from the instants of a ``WaveReading``.
///
/// EARTH MODE ONLY: built only while the mode is Earth (or fading out of
/// it). Every string comes from `EarthText`, which takes the core's Earth
/// forms.
struct WaveEarth: Equatable, Sendable {
    /// The Earth date-time row, field by field (the Earth tumblers).
    var fields: EarthText.EarthFields?
    /// The same as one line, for speech: `THU 8 OCT 2026 · 12:00:00 UTC`.
    var dateLine = ""
    /// Under the Sun's quarters (Peak, Node, Valley, End): `9 OCT 01:34`.
    var sunQuarters: [String] = []
    /// Under the wave's quarters: `12:56:12`, or a date for a long cycle.
    var waveQuarters: [String] = []
    /// When each upcoming threshold falls, in the order of `Live.upcoming`.
    var upcoming: [String] = []

    static func read(_ reading: WaveReading, clock: Catalogue, at instant: Instant, zone: TimeZone) -> WaveEarth {
        var earth = WaveEarth()
        guard let live = reading.live else { return earth }
        earth.fields = EarthText.earthFields(instant, zone: zone)
        earth.dateLine = EarthText.dateLine(instant, zone: zone)
        if let sun = live.sun {
            earth.sunQuarters = sunQuarters(clock, of: sun.sync).map { quarter in
                quarter.map { EarthText.dayClock($0, zone: zone, seconds: false) } ?? ""
            }
        }
        earth.waveQuarters = Quarter.allCases.map { quarter in
            live.points[quarter].map { EarthText.when($0, from: instant, zone: zone) } ?? ""
        }
        earth.upcoming = live.upcoming.map { row in
            row.threshold.instant.map { EarthText.when($0, from: instant, zone: zone) } ?? ""
        }
        return earth
    }

    /// The four quarter boundaries of a sync, each asked of the core: the
    /// next boundary after the sync's start is its Peak, the next after that
    /// its Node, and so on to its End.
    private static func sunQuarters(_ clock: Catalogue, of sync: Sync) -> [Instant?] {
        var boundaries: [Instant?] = []
        var from: Instant? = sync.start
        for _ in Quarter.allCases {
            let next = from.flatMap { try? clock.sync(at: $0).next.instant } ?? nil
            boundaries.append(next)
            from = next
        }
        return boundaries
    }
}
