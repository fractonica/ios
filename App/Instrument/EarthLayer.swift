import Foundation
import FractonicaKit

/// The Earth-mode additions on the instrument (DESIGN.md §9): when each
/// threshold falls, on the bezel words, and the civil days of the running
/// sync hung on the Sun's ring (hour ticks, 6-hour ticks, midnight ticks with
/// the day of the month): 19 Helions against 4 days.
///
/// EARTH MODE ONLY: built and drawn only when the mode is Earth (or fading
/// out of it). Pure mode never constructs one.
struct EarthLayer: Equatable, Sendable {
    /// For each threshold of the focused cycle that is in the catalogue: its
    /// clock time when it falls on the civil day shown (`12:56`), else its
    /// day (`27 SEP`), or its month when it is far (`JAN 2028`): the bezel's
    /// short form; the countdowns under the reading carry the full one.
    var bezelTimes: [Quarter: String] = [:]
    /// The ticks on the Sun's ring.
    var sunTicks: [SunTick] = []

    struct SunTick: Equatable, Sendable {
        enum Kind: Sendable {
            case hour, sixHours, midnight
        }

        /// Where the tick sits on the ring, 0...1 of the sync: the place of
        /// the tick's instant among the sync's 19 Helions, read from the core.
        let fraction: Double
        let kind: Kind
        /// The day of the month, on a midnight tick.
        let label: String?
    }

    static func read(_ reading: InstrumentReading, clock: Catalogue, at instant: Instant, zone: TimeZone) -> EarthLayer {
        var layer = EarthLayer()
        guard let live = reading.live else { return layer }
        for quarter in Quarter.allCases {
            if let at = live.points[quarter] {
                layer.bezelTimes[quarter] = EarthText.bezelWhen(at, from: instant, zone: zone)
            }
        }
        if let sync = live.sun?.sync {
            layer.sunTicks = sunTicks(of: sync, clock: clock, zone: zone)
        }
        return layer
    }

    /// One tick per whole hour of the zone's wall clock inside the sync; the
    /// first instant of each civil day is a midnight tick (also on a day
    /// whose midnight a daylight-saving change skips, which starts at 01:00).
    private static func sunTicks(of sync: Sync, clock: Catalogue, zone: TimeZone) -> [SunTick] {
        ShimCoreGaps.civilHours(from: sync.start, to: sync.end, zone: zone).compactMap { hour in
            // In Helions from the sync's start: the running Helion's place
            // and its phase, the core's (the Sun's lane uses the same line).
            guard let place = WaveTrack.cycles(in: clock, level: Sync.level, from: sync.start, to: hour.instant)
            else { return nil }
            let kind: SunTick.Kind = hour.startsDay ? .midnight : (hour.hour % 6 == 0 ? .sixHours : .hour)
            return SunTick(
                fraction: place / Double(Sync.helions),
                kind: kind,
                // The day of the month, a plain number (fractonica.h, `frc_format_civil_text`).
                label: hour.startsDay ? String(CivilTime(hour.instant, timeZone: zone).day) : nil
            )
        }
    }
}
