import CFractonica

/// A length of time said in Fractonica terms (`frc_span_t`, SPEC §15.4): a
/// signed count of Blinks plus a fraction of one. Spans are measured in
/// **position**, never in seconds, so they stay exact across eclipses.
///
///     let next = try clock.nextThreshold(.helion, after: now)
///     try clock.span(from: now, to: next.instant!).text()      // "6ι 43λ"
///     Level.helion.span.text()                                 // "1η"
///
/// This is how pure mode says every countdown, offset and period.
public struct Span: Hashable, Sendable {
    public var isNegative: Bool
    /// Whole Blinks.
    public var blinks: UInt64
    /// The part of a Blink beyond them.
    public var fraction: Fraction

    public init(isNegative: Bool = false, blinks: UInt64, fraction: Fraction = .zero) {
        self.isNegative = isNegative
        self.blinks = blinks
        self.fraction = fraction
    }

    init(_ raw: frc_span_t) {
        isNegative = raw.negative != 0
        blinks = raw.blinks
        fraction = Fraction(raw: raw.frac)
    }

    var raw: frc_span_t {
        frc_span_t(negative: isNegative ? 1 : 0, blinks: blinks, frac: fraction.raw)
    }

    /// The zero span.
    public static let zero = Span(blinks: 0)

    /// Whether the span has no length at all.
    public var isZero: Bool { blinks == 0 && fraction == .zero }

    /// The span as counts over the unit ladder, greedily from the largest
    /// unit that fits (`frc_span_parts`).
    /// - Parameters:
    ///   - maxParts: at most this many parts (1...9).
    ///   - keepZeros: `false` gives up to `maxParts` non-zero parts; `true`
    ///     the next `maxParts` consecutive units, zeros included.
    /// - Returns: at least one part (a sub-Blink span gives 0 Blinks).
    public func parts(maxParts: Int = Unit.allCases.count, keepZeros: Bool = false) -> [SpanPart] {
        var raw = self.raw
        var buffer = [frc_span_part_t](repeating: frc_span_part_t(), count: Unit.allCases.count)
        let limit = UInt8(clamping: min(max(maxParts, 0), buffer.count))
        let written = frc_span_parts(&raw, limit, keepZeros ? 1 : 0, &buffer)
        return buffer.prefix(Int(written)).compactMap { part in
            Unit(raw: frc_unit_t(UInt32(part.unit))).map { SpanPart(unit: $0, count: part.count) }
        }
    }

    /// The span as text (`frc_format_span`): `"6ι 43λ"`, `"3η 5λ"` (zero
    /// parts skipped), `"−2ε 5η"`; led by the Blink and shorter than 10
    /// Blinks it keeps a decimal, `"2.6ν"`, `"0.14ν"`.
    /// - Parameter maxParts: how many non-zero parts; `nil` is the default
    ///   precision of SPEC §15.4, two.
    public func text(maxParts: Int? = nil) -> String {
        var raw = self.raw
        let limit = UInt8(clamping: maxParts ?? 0)
        return CoreText.infallible { frc_format_span(&raw, limit, $0, $1) }
    }

    /// The span with its direction always said (`frc_format_span_signed`):
    /// `"+6ι 43λ"`, `"−20ι 21λ"`. A text that shows no digit of the span,
    /// `"0ν"` or `"<0.001ν"`, has no sign. Parts as ``text(maxParts:)``.
    public func signedText(maxParts: Int? = nil) -> String {
        var raw = self.raw
        let limit = UInt8(clamping: maxParts ?? 0)
        return CoreText.infallible { frc_format_span_signed(&raw, limit, $0, $1) }
    }

    /// The span counted in whole units of ONE unit, cut toward zero
    /// (`frc_format_span_in_unit`): a drift of −6 236.9 Flavons is
    /// `"−6 236λ"`; never `"−0λ"`.
    public func text(in unit: Unit) -> String {
        var raw = self.raw
        return CoreText.infallible { frc_format_span_in_unit(&raw, unit.raw, $0, $1) }
    }
}

/// One count of a span over the unit ladder (`frc_span_part_t`): 6 Preons.
public struct SpanPart: Hashable, Sendable {
    public let unit: Unit
    public let count: UInt64
}

extension Catalogue {
    /// The span from `start` to `end`, negative when `end` is earlier
    /// (`frc_span_between`). Between two boundaries the core returned
    /// (cycle starts, thresholds, syncs, Pentads, dates) it is the exact
    /// count of units: a Preon's start to its end is `1ι`.
    /// - Throws: ``FractonicaError/outOfRange`` when either instant is outside
    ///   the catalogue.
    public func span(from start: Instant, to end: Instant) throws -> Span {
        Span(try read(into: frc_span_t()) {
            frc_span_between($0, start.microseconds, end.microseconds, $1)
        })
    }

    /// When a countdown's text next changes (`frc_span_next_change`): the
    /// first instant after `now` at which the text of
    /// `span(from: now, to: boundary).text(maxParts:)` differs from its text
    /// at `now`; `boundary` at the latest. Sleep until it, then write the
    /// countdown again.
    /// - Returns: `nil` when `now` is not before `boundary`, or either is
    ///   outside the catalogue.
    public func spanNextChange(from now: Instant, to boundary: Instant, maxParts: Int? = nil) -> Instant? {
        let limit = UInt8(clamping: maxParts ?? 0)
        return Instant(raw: withRaw {
            frc_span_next_change($0, now.microseconds, boundary.microseconds, limit)
        })
    }

    /// The same for a span that GROWS (`frc_span_next_change_since`): the
    /// first instant after `now` at which the text of
    /// `span(from: origin, to: now).text(maxParts:)` differs from its text at
    /// `now`. It schedules an elapsed time since `origin`, and a signed span
    /// to a boundary once the boundary has passed (`span(from: now, to:
    /// boundary)` then has the same length, with a minus). At `origin` the
    /// text is `"0ν"` and the answer is `origin + 1 µs` (`"<0.001ν"`).
    ///
    /// A signed display uses ``spanNextChange(from:to:maxParts:)`` before its
    /// boundary and this from the boundary on.
    /// - Returns: `nil` when `now` is before `origin`, when the text does not
    ///   change again before the catalogue ends (also at its closing
    ///   instant), or either is outside the catalogue.
    public func spanNextChange(since origin: Instant, at now: Instant, maxParts: Int? = nil) -> Instant? {
        let limit = UInt8(clamping: maxParts ?? 0)
        return Instant(raw: withRaw {
            frc_span_next_change_since($0, origin.microseconds, now.microseconds, limit)
        })
    }
}

extension Level {
    /// The nominal length of one cycle of this level (`frc_span_of_level`):
    /// ζ is `11η`, θ `4ι`, ξ `0.14ν`, ρ `<0.001ν`. Exact down to the Blink; below it the
    /// length is cut to 2⁻³² Blink and from level 24 it is the zero span, so
    /// for a rung finer than the Blink say its rate instead
    /// (``cyclesPerBlink()``).
    public var span: Span {
        var raw = frc_span_t()
        _ = frc_span_of_level(self.raw, &raw)
        return Span(raw)
    }
}
