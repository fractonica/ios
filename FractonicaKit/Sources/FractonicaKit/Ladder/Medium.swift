import CFractonica

/// A speed, exact by definition: `numerator / denominator` metres per second
/// (`frc_speed_t`). A period becomes a length through something that travels
/// at one (SPEC §16.3).
public struct Speed: Hashable, Sendable {
    public let numerator: UInt64
    public let denominator: UInt64

    /// A speed of the caller's own (a better figure for its medium).
    public init(numerator: UInt64, denominator: UInt64 = 1) {
        self.numerator = numerator
        self.denominator = denominator
    }

    init(_ raw: frc_speed_t) {
        numerator = raw.num
        denominator = raw.den
    }

    var raw: frc_speed_t { frc_speed_t(num: numerator, den: denominator) }

    /// Light in vacuum, 299 792 458 m/s: the default of every length.
    public static var light: Speed { Medium.vacuum.speed }
}

/// The seven media of SPEC §16.3 (`frc_medium_t`), fastest first. Light in
/// vacuum is exact; the others are nominal benchmarks that make lengths
/// comparable.
public enum Medium: Hashable, Sendable, CaseIterable {
    case vacuum, bounded, diamond, water, air, nerve, chemical

    var raw: frc_medium_t {
        switch self {
        case .vacuum: return FRC_MEDIUM_VACUUM
        case .bounded: return FRC_MEDIUM_BOUNDED
        case .diamond: return FRC_MEDIUM_DIAMOND
        case .water: return FRC_MEDIUM_WATER
        case .air: return FRC_MEDIUM_AIR
        case .nerve: return FRC_MEDIUM_NERVE
        case .chemical: return FRC_MEDIUM_CHEMICAL
        }
    }

    /// The medium's speed (`frc_medium_speed`).
    public var speed: Speed { Speed(frc_medium_speed(raw)) }

    /// A stable identifier, `"vacuum"` (`frc_format_medium_id`).
    public var id: String {
        CoreText.infallible { frc_format_medium_id(raw, $0, $1) }
    }

    /// `"Light in vacuum"` (`frc_format_medium_name`).
    public var name: String {
        CoreText.infallible { frc_format_medium_name(raw, $0, $1) }
    }

    /// The phase of matter, `"Vacuum + solid"` (`frc_format_medium_phase`).
    public var phase: String {
        CoreText.infallible { frc_format_medium_phase(raw, $0, $1) }
    }
}
