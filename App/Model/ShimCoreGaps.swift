import Foundation
import FractonicaKit

// ============================================================================
// TEMPORARY SHIM — the ONE place where the app composes what the core does
// not yet provide (hard rule 1; AGENTS.md rule 9). Nothing of this kind is
// written anywhere else in the app: a view or a reading that needs one of
// these calls it here.
//
// The core now writes the Earth wordings, signed counts and spans, the pure
// wordings of a rung (`9 θ`, `11 in ζ`, `77 in ε`, `8 of 9`, the factor
// chain), the stamp's terms, the Pentad's numeral, the word `light`, the
// glyph of a threshold, the Sun's Helion places, the band edges, durations
// and the parsing of a typed Earth date; their shims are gone. What is left
// waits for the core function named on each:
//
// PURE-SAFE (may be called in either mode): `spanIsLegible`, `placeInBand`.
// EARTH MODE ONLY: `timerTicks`, `oscillatorStep`, `seconds`, `civilHours`,
// `step(_:field:by:zone:)`.
//
// Requested from the core (see the stage reports, core_requests):
//   a way to tell a span the core writes as a number from one it writes as
//     the bound "<0.001ν" (a status or flag from frc_format_span, or
//     int frc_span_is_legible(const frc_span_t *));
//   frc_status_t frc_band_place(uint8_t level, frc_interval_t, frc_frac_t *place);
//   int frc_format_device_ticks(uint8_t level, frc_interval_t, uint64_t rate, char *, size_t);
//   int frc_format_device_step(uint8_t level, frc_interval_t, uint64_t rate, uint8_t bits, char *, size_t);
//   int frc_format_seconds(int64_t microseconds, uint8_t decimals, char *, size_t);
//   frc_status_t frc_civil_step(const frc_civil_t *, frc_civil_field_t field, int32_t n, frc_civil_t *out)
//     (with a zone's offset rule, or a "next whole hour" walk), for civilHours and step.
// ============================================================================

enum ShimCoreGaps {
    // MARK: Pure-safe

    /// Whether the core writes a span as a number (`0.14ν`) rather than as
    /// the bound `<0.001ν` or `0ν` (fractonica.h, `frc_format_span`: below a
    /// thousandth of a Blink). A period that would read as a bound is not
    /// said on the lens; the rung's rate says it instead.
    /// Replace with a status from `frc_format_span` (or `frc_span_is_legible`).
    static func spanIsLegible(_ span: Span) -> Bool {
        span.blinks > 0 || span.fraction.value >= 0.001
    }

    /// Where a rung sits between the edges of its band, 0...1 on a
    /// logarithmic rule (the mark on the ladder's band rule). Unitless, so it
    /// may be drawn in pure mode; a position on a drawing, never a text. The
    /// edges are the core's (`frc_band_edges`), the frequency too; only the
    /// logarithm is taken here. Replace with `frc_band_place`.
    static func placeInBand(_ level: Level, interval: SarosInterval) -> Double? {
        guard let edges = level.band(interval).edges else { return nil }
        let floor = edges.low.value, ceiling = edges.high.value
        let frequency = level.frequencyHertz(interval)
        guard floor > 0, ceiling > floor, frequency > 0 else { return nil }
        return min(max(log(frequency / floor) / log(ceiling / floor), 0), 1)
    }

    // MARK: Earth mode only

    /// A device that makes a rung (SPEC §16.4): the timer and the oscillator
    /// the lens quotes. The numbers are the core's (`frc_device_ticks`,
    /// `frc_device_step`); the rates are this app's choice of example and
    /// are written by the core's quantity formatter.
    static let timerRate: UInt64 = 1_000_000
    static let sampleRate: UInt64 = 48_000
    static let phaseBits = 32

    /// `44 417 ticks at 1 MHz`: one period on a timer; `nil` when the core
    /// refuses (a period under half a tick). The core's count and rate with
    /// the words between them. Replace with `frc_format_device_ticks`.
    static func timerTicks(_ level: Level, interval: SarosInterval) -> String? {
        guard let ticks = try? level.deviceTicks(rate: timerRate, interval: interval),
              let rate = Quantity(digits: timerRate, exponent: 0)
        else { return nil }
        return "\(Fractonica.count(ticks)) ticks at \(rate.text(.frequency, digits: 1))"
    }

    /// `step 2 014 490 at 48 kHz`: the phase increment per sample of a
    /// 32-bit oscillator; `nil` when the core refuses the rung at that rate.
    /// Replace with `frc_format_device_step`.
    static func oscillatorStep(_ level: Level, interval: SarosInterval) -> String? {
        guard let step = try? level.deviceStep(rate: sampleRate, bits: phaseBits, interval: interval),
              let rate = Quantity(digits: sampleRate, exponent: 0)
        else { return nil }
        return "step \(Fractonica.count(step)) at \(rate.text(.frequency, digits: 2))"
    }

    /// `−48 469.99 s`: the Sun's drift in seconds, to the hundredth (DESIGN.md
    /// §9: "drift in s"). The core groups the whole seconds
    /// (`frc_format_count`); the sign, the hundredths and the `s` are set
    /// here. `frc_format_duration` words a duration in d / h / min / s
    /// instead. Replace with `frc_format_seconds`.
    static func seconds(microseconds: Int64) -> String {
        let hundredths = (microseconds.magnitude + 5_000) / 10_000
        let fraction = String(format: "%02d", Int(hundredths % 100))
        let sign = microseconds < 0 ? "−" : ""
        return "\(sign)\(Fractonica.count(hundredths / 100)).\(fraction) s"
    }

    /// A whole hour of the wall clock (minute and second zero), and whether
    /// it is the first instant of its civil day.
    struct CivilHour: Equatable, Sendable {
        let instant: Instant
        /// 0...23 on the wall clock.
        let hour: Int
        /// The day's first instant: midnight, or the hour that replaces a
        /// midnight a daylight-saving change skips.
        let startsDay: Bool
    }

    /// Every whole hour of the zone's wall clock strictly after `start` and
    /// before `end`, with the first instant of each civil day marked. The
    /// calendar is Foundation's, so a change of offset by half an hour (Lord
    /// Howe) or one at midnight (Cairo) puts the hours and days where the
    /// local clock has them. At most 200 (a sync is about 96 hours).
    /// Replace with `frc_civil_step`.
    static func civilHours(from start: Instant, to end: Instant, zone: TimeZone) -> [CivilHour] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        var hours: [CivilHour] = []
        calendar.enumerateDates(
            startingAfter: start.date, matching: DateComponents(minute: 0, second: 0, nanosecond: 0),
            matchingPolicy: .nextTime
        ) { date, _, stop in
            guard let date, Instant(date) < end, hours.count < 200 else {
                stop = true
                return
            }
            hours.append(CivilHour(instant: Instant(date), hour: calendar.component(.hour, from: date),
                                   startsDay: calendar.startOfDay(for: date) == date))
        }
        return hours
    }

    /// The instant `steps` whole Earth units of `field` away from `instant`,
    /// in the calendar of `zone` (an Earth tumbler of the WAVE screen): a
    /// month later is the same day of the next month (the last one when
    /// that month is shorter), an hour later is the next hour on the wall
    /// clock. Calendar arithmetic is Foundation's; the core has none.
    /// `nil` when Foundation cannot say. Replace with `frc_civil_step`.
    static func step(_ instant: Instant, field: EarthField, by steps: Int, zone: TimeZone) -> Instant? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let component: Calendar.Component
        switch field {
        case .day: component = .day
        case .month: component = .month
        case .year: component = .year
        case .hour: component = .hour
        case .minute: component = .minute
        case .second: component = .second
        }
        return calendar.date(byAdding: component, value: steps, to: instant.date).map(Instant.init)
    }
}
