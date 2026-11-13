import CFractonica

/// Several glyphs side by side (`frc_odometer_t`, SPEC §5): the first digit is
/// the coarse phase and each next one runs a full cycle inside one state of
/// its left neighbour. The basic reading on screen is the Helion's odometer
/// of two 2-stroke glyphs (16 × 16 = 256 states per Helion, SPEC §15.3).
///
/// **Redraw at ``nextChange``, do not poll**: the reading taken at that
/// instant already shows the new state.
public struct Odometer: Hashable, Sendable {
    /// Strokes per glyph.
    public let strokes: Int
    /// States per digit, `4M`.
    public let stateCount: Int
    /// Glyph state indices, coarsest first.
    public let digits: [Int]
    /// When the finest digit next changes, strictly after the instant read.
    /// `nil` at the catalogue's closing instant and for an odometer of a bare
    /// phase: nothing to schedule.
    public let nextChange: Instant?

    /// Most digits an odometer can have, 4 (`FRC_MAX_DIGITS`).
    public static let maxDigits = Int(FRC_MAX_DIGITS)

    init(_ raw: frc_odometer_t) {
        strokes = Int(raw.strokes)
        stateCount = Int(raw.states)
        digits = arrayOfTuple(raw.digit, of: UInt16.self).prefix(Int(raw.count)).map(Int.init)
        nextChange = Instant(raw: raw.next_change)
    }

    /// The odometer of a bare fraction of a cycle (`frc_odometer_of_phase`).
    /// - Throws: ``FractonicaError/invalidArgument`` for strokes outside 1...5
    ///   or digits outside 1...4.
    public init(phase: Fraction, strokes: Int = 2, digits: Int = 2) throws {
        guard let strokes = UInt8(exactly: strokes), let digits = UInt8(exactly: digits) else {
            throw FractonicaError.invalidArgument
        }
        var raw = frc_odometer_t()
        try check(frc_odometer_of_phase(phase.raw, strokes, digits, &raw))
        self.init(raw)
    }

    /// The digits as glyphs, ready to draw, coarsest first.
    public var glyphs: [Glyph] {
        digits.compactMap { try? Glyph(index: $0, strokes: strokes) }
    }
}

extension Catalogue {
    /// The odometer of `level` at `instant` (`frc_odometer_at`).
    /// - Parameters:
    ///   - strokes: strokes per glyph, 1...5 (the reference reading uses 2).
    ///   - digits: number of glyphs, 1...4 (the reference reading uses 2).
    /// - Throws: ``FractonicaError/invalidArgument`` for a bad stroke or digit
    ///   count or a level above ``Level/clockMax`` (checked before the
    ///   instant); ``FractonicaError/outOfRange`` outside the catalogue.
    public func odometer(
        _ level: Level, at instant: Instant, strokes: Int = 2, digits: Int = 2
    ) throws -> Odometer {
        guard let strokes = UInt8(exactly: strokes), let digits = UInt8(exactly: digits) else {
            throw FractonicaError.invalidArgument
        }
        return Odometer(try read(into: frc_odometer_t()) {
            frc_odometer_at($0, instant.microseconds, level.raw, strokes, digits, $1)
        })
    }
}
