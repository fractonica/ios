import CFractonica

/// Where a rung's frequency falls among sound and light (`frc_band_t`,
/// SPEC §16.2). A description, not a rule of the clock. The band of a rung
/// depends on the Saros interval the ladder is laid from: see
/// ``Level/band(_:)``.
public enum Band: Hashable, Sendable, CaseIterable {
    /// Below 20 Hz, or from 3.4 × 10²⁹ Hz up: `"no band"` (design/README.md,
    /// ruling 4). It has no edges of its own.
    case noBand
    case audible, radio, microwave, infrared, visible, ultraviolet, xray, gamma

    var raw: frc_band_t {
        switch self {
        case .noBand: return FRC_BAND_NONE
        case .audible: return FRC_BAND_AUDIBLE
        case .radio: return FRC_BAND_RADIO
        case .microwave: return FRC_BAND_MICROWAVE
        case .infrared: return FRC_BAND_INFRARED
        case .visible: return FRC_BAND_VISIBLE
        case .ultraviolet: return FRC_BAND_ULTRAVIOLET
        case .xray: return FRC_BAND_XRAY
        case .gamma: return FRC_BAND_GAMMA
        }
    }

    init(raw: frc_band_t) {
        self = Band.allCases.first(where: { $0.raw == raw }) ?? .noBand
    }

    /// `"audible"`, `"gamma ray"`; `"no band"` for ``noBand`` (`frc_format_band`).
    public var name: String {
        CoreText.infallible { frc_format_band(raw, $0, $1) }
    }

    /// The edges of the band in hertz, exactly as SPEC §16.2 tabulates them
    /// (`frc_band_edges`): `low` it starts at (and holds), `high` where the
    /// next band starts. Visible light is 400 THz to 790 THz. Write them with
    /// `text(.frequency, digits: 2)`, which gives the SPEC's figures.
    /// **Earth mode only** (hertz). `nil` for ``noBand``, which is two open
    /// ranges (below audible's low edge, from gamma's high edge up).
    public var edges: (low: Quantity, high: Quantity)? {
        var low = frc_sci_t(), high = frc_sci_t()
        guard frc_band_edges(raw, &low, &high) == FRC_OK else { return nil }
        return (Quantity(low), Quantity(high))
    }
}
