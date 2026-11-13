import CoreGraphics

/// The four screens (design/README.md ruling 4). The raw value is the word a
/// launch argument and a snapshot file name use; ``word`` is what is engraved.
enum Screen: String, CaseIterable, Sendable {
    case now, ladder, lens, wave

    /// `NOW`, `LADDER`, `LENS`, `WAVE`.
    var word: String { rawValue.uppercased() }

    /// The Mac's hover hint on its sigil: what the screen is, and its key.
    /// Fractonica words only (it is shown in pure mode too).
    var hint: String {
        switch self {
        case .now: return "Now: the instrument at the moment shown (⌘1)"
        case .ladder: return "Ladder: the spectral catalogue of all 63 rungs (⌘2)"
        case .lens: return "Lens: everything about one rung (⌘3)"
        case .wave: return "Wave: the timeline, to move through time (⌘4)"
        }
    }
}

/// Pure shows only Fractonica; Earth adds the Gregorian translation where
/// DESIGN.md §9 says, led by the Earth sign.
enum DisplayMode: String, CaseIterable, Sendable {
    case pure, earth

    /// `PURE`, `EARTH`: the label of the toggle.
    var word: String { rawValue.uppercased() }
    var toggled: DisplayMode { self == .pure ? .earth : .pure }
}

/// The two arrangements of DESIGN.md §7. Every screen is drawn in the design
/// space of its class and scaled as a whole (see `Design/DesignSpace.swift`).
enum LayoutClass: String, CaseIterable, Sendable {
    /// 393 × 852, safe areas included (59 top, 34 bottom).
    case phone
    /// 1280 × 800: left rail, instrument, right column. A wide Mac window, an iPad.
    case desktop

    /// The size the design was drawn at, in points.
    var designSize: CGSize {
        switch self {
        case .phone: return CGSize(width: 393, height: 852)
        case .desktop: return CGSize(width: 1280, height: 800)
        }
    }

    /// The safe bands the design itself keeps at its top and bottom: the
    /// phone design is an iPhone 16 Pro's screen, status bar and home
    /// indicator included; the desktop design has none.
    var safeBands: (top: CGFloat, bottom: CGFloat) {
        switch self {
        case .phone: return (59, 34)
        case .desktop: return (0, 0)
        }
    }

    /// The arrangement for a view of `size` (DESIGN.md §7).
    /// - iOS: an iPad full screen, in either orientation, or in a wide part
    ///   of Split View, is the desktop ("on iPad use the desktop
    ///   arrangement"): any view 700 pt wide or more. Anything narrower (a
    ///   phone, which is portrait only, or a narrow split of an iPad) is the
    ///   phone arrangement.
    /// - Mac: a window wider than tall (by 15 %) and at least 700 pt wide is
    ///   the desktop; a narrow or tall window (half of a laptop's screen)
    ///   gets the phone arrangement, a column that fits it.
    static func fitting(_ size: CGSize) -> LayoutClass {
        #if os(macOS)
        return size.width >= size.height * 1.15 && size.width >= 700 ? .desktop : .phone
        #else
        return size.width >= 700 ? .desktop : .phone
        #endif
    }
}
