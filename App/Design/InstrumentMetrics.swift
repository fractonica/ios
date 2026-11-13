import CoreGraphics

/// The measures of the instrument in design points (DESIGN.md §5–7), for one
/// arrangement. All of the instrument's and the limb's drawing reads its
/// numbers from here, so a smaller instrument (the lens's inspector ring) is
/// another value of this type, not another renderer.
struct InstrumentMetrics: Equatable, Sendable {
    /// Centre of the instrument.
    var center: CGPoint
    /// Radius R of the carrier of the hero ring.
    var radius: CGFloat
    /// Nested levels drawn on the carrier: 2 on the phone, 3 on the desktop.
    var nestDepth: Int
    /// Gap between minor counter rings (g) and between major ones (gM).
    var ringGap: CGFloat
    var majorRingGap: CGFloat
    /// The outermost counter ring never passes this radius; the gaps are
    /// compressed when a deep focus has more ancestors than fit.
    var maxOuterRadius: CGFloat
    /// Whether this is the large (desktop) instrument: heavier hero line,
    /// larger beads, ticks and letters.
    var isLarge: Bool
    /// Points per glyph design unit of the centre odometer.
    var glyphUnit: CGFloat
    /// The limb: radius of the letters, degrees per letter, letters each side.
    var limbRadius: CGFloat
    var limbStepDegrees: CGFloat
    var limbSpan: Int
    /// Whether the counter rings, the alidade and the words are drawn. The
    /// lens's small ring switches them off.
    var showsOrrery = true
    var showsWords = true

    /// Phone: centre (196.5, 277), R 102, the limb on r 209 (DESIGN.md §7).
    static let phone = InstrumentMetrics(
        center: CGPoint(x: 196.5, y: 277), radius: 102, nestDepth: 2,
        ringGap: 9.5, majorRingGap: 6.5, maxOuterRadius: 186.3, isLarge: false,
        glyphUnit: 8.8, limbRadius: 209, limbStepDegrees: 8.2, limbSpan: 5
    )

    /// Desktop: centre (452, 384), R 172, the limb on r 352.
    static let desktop = InstrumentMetrics(
        center: CGPoint(x: 452, y: 384), radius: 172, nestDepth: 3,
        ringGap: 13, majorRingGap: 10.5, maxOuterRadius: 305.7, isLarge: true,
        glyphUnit: 12.7, limbRadius: 352, limbStepDegrees: 5.6, limbSpan: 7
    )

    /// The NOW screen's instrument for an arrangement.
    static func standard(_ layout: LayoutClass) -> InstrumentMetrics {
        layout == .desktop ? .desktop : .phone
    }

    /// A bare ring of radius `radius` at `center`: the hero ring, its beads,
    /// bezel and glyphs, with two nested levels and no orrery or words (the
    /// lens's inspector ring, R 54).
    static func inspector(center: CGPoint, radius: CGFloat) -> InstrumentMetrics {
        InstrumentMetrics(
            center: center, radius: radius, nestDepth: 2,
            ringGap: 0, majorRingGap: 0, maxOuterRadius: radius * 1.37, isLarge: false,
            glyphUnit: radius * 0.086, limbRadius: 0, limbStepDegrees: 8.2, limbSpan: 0,
            showsOrrery: false, showsWords: false
        )
    }

    // MARK: Derived measures (the `big ? a : b` pairs of the design)

    /// The inner bezel sits at 0.71 R.
    var bezelRadius: CGFloat { radius * 0.71 }
    /// The first counter ring sits at 1.37 R.
    var firstRingRadius: CGFloat { radius * 1.37 }
    var beadRadius: CGFloat { isLarge ? 2.4 : 1.8 }
    var nowPointRadius: CGFloat { isLarge ? 3.2 : 2.6 }
    var graduationLength: CGFloat { isLarge ? 3.6 : 2.4 }
    var longGraduationLength: CGFloat { isLarge ? 7 : 4.6 }
    var thresholdTickLength: CGFloat { isLarge ? 9 : 6 }
    /// The bezel words sit this far inside the bezel.
    var bezelWordInset: CGFloat { isLarge ? 18 : 12.5 }
    var bezelWordSize: CGFloat { isLarge ? 8 : 6.2 }
    var titleSize: CGFloat { isLarge ? 19 : 12.5 }
    var ringLetterSize: CGFloat { isLarge ? 10 : 8 }
    var ringLetterOffset: CGFloat { isLarge ? 12 : 9.5 }
    var limbLetterSize: CGFloat { isLarge ? 16 : 13 }
    var limbFocusLetterSize: CGFloat { isLarge ? 26 : 20 }
    /// The limb's scale line runs this far inside the letters.
    var limbRuleInset: CGFloat { isLarge ? 20 : 14 }
    /// The index notch sits this far outside the letters.
    var limbNotchOffset: CGFloat { isLarge ? 22 : 17 }
}
