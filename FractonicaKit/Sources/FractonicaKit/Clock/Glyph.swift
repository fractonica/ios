import CFractonica

/// One state of a phase glyph (`frc_glyph_t`, SPEC §4): the phase of a cycle
/// written as a balanced-ternary numeral of 1...5 strokes.
///
/// A glyph of `d` strokes has `4M` states, `M = (3^d − 1) / 2`: 16 states for
/// 2 strokes, 52 for 3. To draw one see `Geometry/GlyphPath.swift`
/// (``path``, ``outline(unit:origin:)``).
public struct Glyph: Hashable, Sendable {
    /// State index, `0 ..< 4M`.
    public let index: Int
    /// The value, `−M ... +M`.
    public let value: Int
    /// +1 rising, 0 at peak and valley, −1 falling.
    public let derivative: Int
    /// Whether the dot is drawn: on the falling branch only (SPEC pitfall 5).
    public let isDotted: Bool
    /// Number of strokes, 1...5.
    public let strokes: Int
    /// The balanced-ternary digits, −1 / 0 / +1, **least significant first**
    /// (the first is drawn at the top, SPEC §9.1). `strokes` entries.
    public let trits: [Int]

    /// Most strokes a glyph can have, 5 (`FRC_MAX_STROKES`).
    public static let maxStrokes = Int(FRC_MAX_STROKES)

    init(_ raw: frc_glyph_t) {
        index = Int(raw.index)
        value = Int(raw.value)
        derivative = Int(raw.derivative)
        isDotted = raw.dotted != 0
        strokes = Int(raw.strokes)
        trits = arrayOfTuple(raw.trit, of: Int8.self).prefix(Int(raw.strokes)).map(Int.init)
    }

    /// State `index` (taken modulo the number of states) of a glyph of
    /// `strokes` strokes (`frc_glyph_from_index`).
    /// - Throws: ``FractonicaError/invalidArgument`` for strokes outside 1...5.
    public init(index: Int, strokes: Int = 2) throws {
        guard let index = UInt16(exactly: index), let strokes = UInt8(exactly: strokes) else {
            throw FractonicaError.invalidArgument
        }
        var raw = frc_glyph_t()
        try check(frc_glyph_from_index(index, strokes, &raw))
        self.init(raw)
    }

    /// The glyph of a bare fraction of a cycle: state `floor(phase * 4M)`
    /// (`frc_glyph_index_of_phase`).
    public init(phase: Fraction, strokes: Int = 2) throws {
        let strokeCount = UInt8(clamping: strokes)
        try self.init(index: Int(frc_glyph_index_of_phase(phase.raw, strokeCount)), strokes: strokes)
    }

    /// The glyph state a cycle shows at the threshold that ends `quarter`
    /// (`frc_glyph_at_quarter`, SPEC §6.2): the Peak is state M (phase ¼),
    /// the Node 2M (½), the Valley 3M (¾) and the End state 0, the next
    /// cycle's start. With 2 strokes: 4, 8, 12 and 0.
    /// - Throws: ``FractonicaError/invalidArgument`` for strokes outside 1...5.
    public init(at quarter: Quarter, strokes: Int = 2) throws {
        guard let strokes = UInt8(exactly: strokes) else { throw FractonicaError.invalidArgument }
        var raw = frc_glyph_t()
        try check(frc_glyph_at_quarter(quarter.raw, strokes, &raw))
        self.init(raw)
    }

    /// The glyph as the core takes it. Decoded again from the index, so the
    /// kit never copies the core's fields by hand.
    var raw: frc_glyph_t {
        var raw = frc_glyph_t()
        _ = frc_glyph_from_index(UInt16(clamping: index), UInt8(clamping: strokes), &raw)
        return raw
    }

    /// `M`, the extreme value of a glyph of `strokes` strokes
    /// (`frc_glyph_extreme`); 0 for an invalid stroke count.
    public static func extreme(strokes: Int) -> Int {
        Int(frc_glyph_extreme(UInt8(clamping: strokes)))
    }

    /// `4M`, the number of states (`frc_glyph_states`): 16, 52, 160 ...
    public static func stateCount(strokes: Int) -> Int {
        Int(frc_glyph_states(UInt8(clamping: strokes)))
    }

    /// The same state in the descending family, `(index + 2M) mod 4M`
    /// (`frc_glyph_index_descending`).
    public var descending: Glyph {
        let index = frc_glyph_index_descending(UInt16(clamping: self.index), UInt8(clamping: strokes))
        var raw = frc_glyph_t()
        _ = frc_glyph_from_index(index, UInt8(clamping: strokes), &raw)
        return Glyph(raw)
    }
}

extension Catalogue {
    /// The glyph of `level` at `instant`, ascending family (`frc_glyph_at`).
    /// It equals the first digit of ``odometer(_:at:strokes:digits:)``.
    public func glyph(_ level: Level, at instant: Instant, strokes: Int = 2) throws -> Glyph {
        guard let strokes = UInt8(exactly: strokes) else { throw FractonicaError.invalidArgument }
        return Glyph(try read(into: frc_glyph_t()) {
            frc_glyph_at($0, instant.microseconds, level.raw, strokes, $1)
        })
    }
}
