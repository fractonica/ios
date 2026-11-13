import CFractonica

/// Facts about the library itself, and the two text utilities that belong to
/// no type.
public enum Fractonica {
    /// Version of the C core this kit is linked with, e.g. `"0.2.0"`.
    public static var coreVersion: String { FRC_VERSION }

    /// Version of SPEC.md the core implements, e.g. `"2.2.0"`.
    public static var specVersion: String { FRC_SPEC_VERSION }

    /// Fracton ordinal (SPEC §15.2): `"Monofracton"` (1) ... `"Icosafracton"`
    /// (20); beyond that `"#25"`.
    public static func ordinal(_ n: Int) -> String {
        CoreText.infallible { frc_format_ordinal(UInt16(clamping: n), $0, $1) }
    }

    /// Any text of this library as plain ASCII, for logs and for places that
    /// cannot show Greek: `α β γ δ ε ζ η …` become `a b g d e z h …`, `−`
    /// becomes `-`, `⬠` becomes `P`. ``FractonicaDate/init(parsing:context:)``
    /// reads the result back.
    public static func ascii(_ text: String) -> String {
        // No replacement is longer than the bytes it replaces (even the caret
        // that opens a run of superscripts: a superscript is two bytes or more),
        // so a buffer of the input's size plus a margin always holds the output.
        CoreText.infallible(minimumCapacity: text.utf8.count + 16) { frc_to_ascii(text, $0, $1) }
    }
}
