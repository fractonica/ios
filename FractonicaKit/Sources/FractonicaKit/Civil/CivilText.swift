import CFractonica

// EARTH WORDING (fractonica.h, "EARTH WORDING"): the dates, clock times and
// durations Earth mode shows, written by the core so that the clients do not
// each compose their own. EARTH MODE ONLY, like everything in `Civil/`.
//
// The core cannot know a zone's abbreviation (`CEST`): a view that shows one
// appends the platform's after the text (design/README.md ruling 6).

/// The forms of an Earth text (`frc_civil_form_t`), at vector A in UTC.
public enum CivilForm: Hashable, Sendable, CaseIterable {
    /// `THU 8 OCT 2026 · 12:00:00`: the date line.
    case dateTime
    /// `THU 8 OCT 2026`
    case date
    /// `12:00:00`: a moment of the day shown.
    case time
    /// `12:00`: the bezel's `END 12:56`.
    case minute
    /// `8 OCT`
    case dayMonth
    /// `9 OCT 01:34`: another day, to the minute.
    case dayMonthTime
    /// `JAN 2028`
    case monthYear
    /// `UTC+3`, `UTC−2:30`, `UTC`: the offset alone (``CivilTime/offsetText(seconds:)``).
    case offset
    /// `3 FEB 2028`: a moment far away.
    case dayMonthYear
    /// `9 OCT 01:34:05`
    case dayMonthSeconds
    /// `2026-10-08`
    case isoDate
    /// `THU`
    case weekday
    /// `OCT`
    case month
    /// `2026`
    case year

    var raw: frc_civil_form_t {
        switch self {
        case .dateTime: return FRC_CIVIL_DATE_TIME
        case .date: return FRC_CIVIL_DATE
        case .time: return FRC_CIVIL_TIME
        case .minute: return FRC_CIVIL_MINUTE
        case .dayMonth: return FRC_CIVIL_DAY_MONTH
        case .dayMonthTime: return FRC_CIVIL_DAY_MONTH_TIME
        case .monthYear: return FRC_CIVIL_MONTH_YEAR
        case .offset: return FRC_CIVIL_OFFSET
        case .dayMonthYear: return FRC_CIVIL_DAY_MONTH_YEAR
        case .dayMonthSeconds: return FRC_CIVIL_DAY_MONTH_SECONDS
        case .isoDate: return FRC_CIVIL_ISO_DATE
        case .weekday: return FRC_CIVIL_WEEKDAY
        case .month: return FRC_CIVIL_MONTH
        case .year: return FRC_CIVIL_YEAR
        }
    }
}

extension CivilTime {
    /// The fields in one of the Earth forms (`frc_format_civil_text`):
    /// `.dateTime` is `"THU 8 OCT 2026 · 12:00:00"`, `.dayMonthTime`
    /// `"9 OCT 01:34"`. The fields are said as they are, nothing is rounded;
    /// the weekday is computed from the date; a year outside 1...9999 has
    /// four digits at least and a sign unless it is 0 (`"−0044"`, U+2212;
    /// `.isoDate` alone writes ISO 8601's hyphen-minus, `"-0044-03-15"`).
    /// `.offset` writes ``utcOffsetSeconds``.
    /// - Returns: `nil` unless the fields name a real moment (``isValid``),
    ///   and for `.offset` an offset of a day or more either way.
    public func text(_ form: CivilForm) -> String? {
        guard var raw = exactRaw, let offset = Int32(exactly: utcOffsetSeconds) else { return nil }
        return try? CoreText.make { frc_format_civil_text(&raw, offset, form.raw, $0, $1) }
    }

    /// An offset from UTC alone (`frc_format_civil_text`, `FRC_CIVIL_OFFSET`):
    /// `"UTC+3"`, `"UTC−2:30"`, and `"UTC"` for zero (and for an offset under
    /// a minute). Cut toward zero to whole minutes; at most `"UTC+23:59"`.
    /// - Returns: `nil` for an offset of a day or more either way
    ///   (|seconds| ≥ 86 400), which the core refuses.
    public static func offsetText(seconds: Int) -> String? {
        guard let offset = Int32(exactly: seconds) else { return nil }
        return try? CoreText.make { frc_format_civil_text(nil, offset, FRC_CIVIL_OFFSET, $0, $1) }
    }
}

extension Fractonica {
    /// An Earth duration (`frc_format_duration`): `"23 min 53 s"`,
    /// `"1 h 2 min"`, `"3 d 4 h"`, `"0.4 s"`, `"9.27 s"`.
    ///
    /// Rounded ONCE, then worded: below 9.995 s to the hundredth (trailing
    /// zeros dropped); from there the leading unit is the largest that fits
    /// (d, h, min, s) and the duration is rounded, a half going up, to the
    /// finest of `maxParts` consecutive units, zero parts not written. So
    /// 59.6 s is `"1 min"`, never `"60 s"`. A negative duration is led by
    /// U+2212. **Earth mode only.**
    /// - Parameter maxParts: 1...4 (`nil`: 2).
    public static func duration(microseconds: Int64, maxParts: Int? = nil) -> String {
        let parts = UInt8(clamping: maxParts ?? 0)
        return CoreText.infallible { frc_format_duration(microseconds, parts, $0, $1) }
    }
}
