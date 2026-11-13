import Foundation
import FractonicaKit

/// Earth mode's texts (DESIGN.md §9): which of the core's Earth forms each
/// line uses, at which instant, and the zone's abbreviation the core cannot
/// know (fractonica.h, "EARTH WORDING"; design/README.md ruling 6).
///
/// EARTH MODE ONLY: nothing here may be called in pure mode. Every word and
/// number is the core's (`CivilTime.text(_:)`, `Fractonica.duration`,
/// `CivilTime.parse`); this file chooses the form (the header's table maps
/// each line of this app to one), the instant (the moment shown cut to its
/// second, a threshold rounded to its nearest), and appends the platform's
/// zone abbreviation after the date line. Calendar arithmetic the core does
/// not have yet stays in `ShimCoreGaps` (`civilHours`, `step`).
enum EarthText {
    /// `THU 8 OCT 2026 · 12:00:00 UTC`: the line under the reading
    /// (`.dateTime`, then the zone's abbreviation: the one place it is shown).
    static func dateLine(_ instant: Instant, zone: TimeZone) -> String {
        let text = momentFields(instant, zone: zone).text(.dateTime) ?? ""
        return "\(text) \(zoneAbbreviation(zone, at: instant))"
    }

    /// `12:56` or `12:56:12`: the clock time of a threshold (`.minute`, `.time`).
    static func clock(_ instant: Instant, zone: TimeZone, seconds: Bool) -> String {
        thresholdFields(instant, zone: zone).text(seconds ? .time : .minute) ?? ""
    }

    /// `9 OCT 01:34` or `9 OCT 01:34:05`: a moment on another day
    /// (`.dayMonthTime`, `.dayMonthSeconds`).
    static func dayClock(_ instant: Instant, zone: TimeZone, seconds: Bool) -> String {
        thresholdFields(instant, zone: zone).text(seconds ? .dayMonthSeconds : .dayMonthTime) ?? ""
    }

    /// When a threshold falls, as short as the distance from `now` allows,
    /// so that a time of day is never shown without its day when the day is
    /// another one: the clock time on the same civil day (`12:56:12`, or
    /// `12:56` without `seconds`), day and time within 300 days
    /// (`9 OCT 01:34`), else the date (`3 FEB 2028`). Used by every screen
    /// for a threshold (the NOW countdowns, the lens, the wave), so one
    /// threshold reads the same everywhere; the bezel's words use the short
    /// form of the same rule (``bezelWhen(_:from:zone:)``).
    static func when(_ instant: Instant, from now: Instant, zone: TimeZone, seconds: Bool = true) -> String {
        let civil = thresholdFields(instant, zone: zone)
        if isSameDay(civil, momentFields(now, zone: zone)) {
            return civil.text(seconds ? .time : .minute) ?? ""
        }
        return civil.text(isWithin300Days(instant, of: now) ? .dayMonthTime : .dayMonthYear) ?? ""
    }

    /// The short form of ``when(_:from:zone:seconds:)`` for the words that
    /// run along the instrument's bezel, where a long text would cross the
    /// graduations: the clock time on the day shown (`12:56`, the design's
    /// `END 12:56`), the day within 300 days (`27 SEP`), else the month and
    /// year (`JAN 2028`). Never a time of day without its day.
    static func bezelWhen(_ instant: Instant, from now: Instant, zone: TimeZone) -> String {
        let civil = thresholdFields(instant, zone: zone)
        if isSameDay(civil, momentFields(now, zone: zone)) {
            return civil.text(.minute) ?? ""
        }
        return civil.text(isWithin300Days(instant, of: now) ? .dayMonth : .monthYear) ?? ""
    }

    /// `56 min 12 s`, `5 h 3 min`, `4 d 2 h`, `41 s`, `9.27 s`: the time to a
    /// threshold, in two parts, worded by the core (`frc_format_duration`,
    /// which rounds once and then words: `1 min`, never `60 s`).
    ///
    /// Under ten seconds it is the exact interval, to the hundredth. From
    /// ten seconds up it is the whole seconds between the two clock readings
    /// as they are shown (the moment `start` cut to its second, the
    /// threshold `end` to its nearest second), so `12:00:00` and
    /// `5 min 41 s` add up to the `12:05:41` printed beside them, and the
    /// text changes exactly when the clock's second does.
    static func duration(from start: Instant, to end: Instant) -> String {
        let exact = end.microseconds(since: start).magnitude
        if exact < 9_995_000 {
            return Fractonica.duration(microseconds: Int64(exact))
        }
        // At least ten: the two readings can be a second short of the exact
        // value just above it (9.996 s from 12:00:00.000 ends at 12:00:09).
        let shownEnd = wholeSecond(end.advanced(byMicroseconds: 500_000))
        let whole = max(abs(shownEnd - wholeSecond(start)), 10)
        return Fractonica.duration(microseconds: whole * 1_000_000)
    }

    /// The first instant after `now` at which an Earth text on screen can
    /// change: the next whole second of the clock (every zone is a whole
    /// number of seconds from UTC, so the seconds of all zones turn
    /// together). What the scheduler adds in Earth mode, so the seconds of
    /// the date line and the tumblers turn on time (hard rule 4).
    static func nextEarthSecond(after now: Instant) -> Instant {
        Instant(microseconds: (wholeSecond(now) + 1) * 1_000_000)
    }

    /// Reads a typed Earth date (`frc_parse_civil`): `2026-10-08`,
    /// `2026-10-08 12:00`, `2026-10-08T14:00:00+02:00`, `8 OCT 2026
    /// 12:00:00`, `THU 8 OCT 2026 · 12:00:00`. A time without a zone is the
    /// wall clock of `zone`. `nil` for anything else, and for a day or time
    /// that does not exist (`31 FEB`).
    static func instant(parsing text: String, zone: TimeZone) -> Instant? {
        guard let parsed = try? CivilTime.parse(text) else { return nil }
        return parsed.namesOffset ? parsed.time.instant : parsed.time.instant(in: zone)
    }

    // MARK: The Earth tumblers of the WAVE screen

    /// The Earth date-time split into the pieces of the tumbler row:
    /// `THU` · `8` `OCT` `2026` · `12` `00` `00` · `UTC`. The words are the
    /// core's (`.weekday`, `.month`, `.year`); the day, hours, minutes and
    /// seconds are plain numbers (fractonica.h, the table under
    /// `frc_format_civil_text`), the clock's two digits wide.
    struct EarthFields: Equatable, Sendable {
        var weekday: String
        var day: String
        var month: String
        var year: String
        var hour: String
        var minute: String
        var second: String
        /// The zone's abbreviation at that instant.
        var zone: String

        subscript(field: EarthField) -> String {
            switch field {
            case .day: return day
            case .month: return month
            case .year: return year
            case .hour: return hour
            case .minute: return minute
            case .second: return second
            }
        }
    }

    /// The fields of ``dateLine(_:zone:)``, one by one.
    static func earthFields(_ instant: Instant, zone: TimeZone) -> EarthFields {
        let civil = momentFields(instant, zone: zone)
        return EarthFields(
            weekday: civil.text(.weekday) ?? "", day: String(civil.day), month: civil.text(.month) ?? "",
            year: civil.text(.year) ?? "", hour: String(format: "%02d", civil.hour),
            minute: String(format: "%02d", civil.minute), second: String(format: "%02d", civil.second),
            zone: zoneAbbreviation(zone, at: instant)
        )
    }

    // MARK: Pieces

    /// The zone's abbreviation at an instant (the platform's: the core cannot
    /// know one); the fixed zero zone is written UTC (Foundation
    /// abbreviates it GMT).
    private static func zoneAbbreviation(_ zone: TimeZone, at instant: Instant) -> String {
        let isZeroZone = zone.identifier == "GMT" || zone.identifier == "UTC"
        return isZeroZone ? "UTC" : (zone.abbreviation(for: instant.date) ?? zone.identifier)
    }

    /// The civil fields of THE MOMENT SHOWN, cut to the second as a wall
    /// clock shows it: never ahead of the device's own clock (23:59:59.6 is
    /// still the day before). The fields are the core's; its text forms
    /// show seconds and never round.
    private static func momentFields(_ instant: Instant, zone: TimeZone) -> CivilTime {
        CivilTime(instant, timeZone: zone)
    }

    /// The civil fields of A THRESHOLD, to its nearest second: the core
    /// returns the first microsecond at or after an exact boundary, which is
    /// rarely on a whole second (the Helion's Node at A falls at 10:24:37.6
    /// and is said `10:24:38`, as the design prints it).
    /// ``duration(from:to:)`` counts to the same second.
    private static func thresholdFields(_ instant: Instant, zone: TimeZone) -> CivilTime {
        CivilTime(instant.advanced(byMicroseconds: 500_000), timeZone: zone)
    }

    private static func isSameDay(_ one: CivilTime, _ other: CivilTime) -> Bool {
        (one.year, one.month, one.day) == (other.year, other.month, other.day)
    }

    private static func isWithin300Days(_ instant: Instant, of now: Instant) -> Bool {
        abs(instant.microseconds(since: now)) / 86_400_000_000 < 300
    }

    /// The Unix second an instant is in (floored, also before 1970).
    private static func wholeSecond(_ instant: Instant) -> Int64 {
        let (quotient, remainder) = instant.microseconds.quotientAndRemainder(dividingBy: 1_000_000)
        return remainder < 0 ? quotient - 1 : quotient
    }
}
