import CFractonica

/// The four quarters of a cycle, each **named by the threshold that ends it**
/// (SPEC §6.2, `frc_quarter_t`): a cycle "in its Peak quarter" is rising
/// towards its peak.
///
/// The same type names a threshold (``Threshold/quarter``): the Peak
/// threshold is the instant at 1/4 of the cycle, End the instant the next
/// cycle begins.
public enum Quarter: Hashable, Sendable, CaseIterable, Comparable {
    /// Ends at 1/4: the glyph value reaches +M.
    case peak
    /// Ends at 2/4: value 0, falling.
    case node
    /// Ends at 3/4: value −M.
    case valley
    /// Ends at 4/4: the next cycle begins.
    case end

    /// The quarter as the core takes it.
    var raw: frc_quarter_t {
        switch self {
        case .peak: return FRC_PEAK
        case .node: return FRC_NODE
        case .valley: return FRC_VALLEY
        case .end: return FRC_END
        }
    }

    /// A value from a `uint8_t` struct field of the core (`frc_cycle_t.quarter`,
    /// `frc_threshold_t.name`). A value outside the enum reads as `.peak`,
    /// which is also what the core stores when a quarter does not apply.
    init(field: UInt8) {
        let raw = frc_quarter_t(UInt32(field))
        self = Quarter.allCases.first(where: { $0.raw == raw }) ?? .peak
    }

    /// `"Peak"`, `"Node"`, `"Valley"`, `"End"` (`frc_format_quarter`).
    public var name: String { name(lowercase: false) }

    /// The same, or `"peak"`, `"node"` ... when `lowercase`.
    public func name(lowercase: Bool) -> String {
        CoreText.infallible { frc_format_quarter(raw, lowercase ? 1 : 0, $0, $1) }
    }
}
