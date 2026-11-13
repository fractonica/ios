import Foundation
import FractonicaKit

/// What assistive technology says for the rings of the instrument: each ring
/// is one element whose label is its name and whose value is its reading in
/// the current mode (hard rule 7 of the brief).
///
/// The readings are the core's texts, as on screen. Pure mode says nothing
/// Earthly: the Earth parts are appended only when `zone` is given, which the
/// caller does in Earth mode alone.
enum InstrumentSpeech {
    /// The hero ring: `Helion ring`.
    static func heroLabel(_ reading: InstrumentReading) -> String {
        "\(reading.spokenName) ring"
    }

    /// `ε#5 34η, End in 6ι 43λ` (Earth mode adds `, Earth 12:56:12`).
    static func heroValue(_ reading: InstrumentReading, outOfCatalogue: String, zone: TimeZone?) -> String {
        guard let live = reading.live else { return outOfCatalogue }
        var value = "\(live.cycle.name), \(live.nextThreshold.quarter.name) in \(live.nextSpan)"
        if let zone, let instant = live.nextThreshold.instant {
            value += ", Earth \(EarthText.clock(instant, zone: zone, seconds: true))"
        }
        return value
    }

    /// A counter ring: `Nuclide ring`, `Zeta ring`.
    static func counterLabel(_ counter: CounterReading) -> String {
        "\(counter.level.unit?.name ?? counter.level.word) ring"
    }

    /// `Delta Trifracton, End`.
    static func counterValue(_ counter: CounterReading, outOfCatalogue: String) -> String {
        guard let live = counter.live else { return outOfCatalogue }
        return "\(live.cycle.name), \(live.cycle.quarter.name)"
    }

    /// The Sun's ring.
    static let sunLabel = "Sun ring"

    /// `Solar sync 4 820, Pentad II, 2nd Helion, Node in 2η 24ι`.
    static func sunValue(_ now: NowReading, zone: TimeZone?) -> String {
        guard let sun = now.live?.sun else { return now.pentad?.name ?? now.outOfCatalogue }
        var parts = ["Solar sync \(sun.number)"]
        if let pentad = now.pentad?.text(.full, withHelion: true) { parts.append(pentad) }
        parts.append("\(sun.sync.next.quarter.name) in \(sun.nextSpan)")
        if let zone, let instant = sun.sync.next.instant {
            parts.append("Earth \(EarthText.dayClock(instant, zone: zone, seconds: true))")
        }
        return parts.joined(separator: ", ")
    }
}
