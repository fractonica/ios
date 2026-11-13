import SwiftUI

/// THE token table: every colour, typeface, line weight and glow of the app.
///
/// No colour or font is written anywhere else. A view takes the theme from
/// the environment (`@Environment(\.theme)`), a renderer from `ink.theme`.
/// The names are those of design/astrolabe/DESIGN.md §2–4; a second theme
/// (Basalt, design/tablet) is another value of this same type, chosen with
/// `--theme basalt`.
///
///     Theme.astrolabe      Design/Theme+Astrolabe.swift   (default)
///     Theme.basalt         Design/Theme+Basalt.swift
struct Theme: Sendable {
    let name: String
    let palette: Palette
    let type: Typography
    let line: LineWeights
    let glow: Glow
    /// The smallest engraved size, in design points, that ``engraved(_:_:tracking:)``
    /// sets: 0 at the design's own scale. A canvas raises it where the phone
    /// design is drawn smaller than designed (``DesignSpace/engravedFloor``).
    var engravedFloor: CGFloat = 0

    /// The theme a `--theme` argument names; Astrolabe for anything else.
    static func named(_ name: String?) -> Theme {
        name == Theme.basalt.name ? .basalt : .astrolabe
    }
}

/// Colour tokens (DESIGN.md §2). Light means elapsed; engraving means not yet.
struct Palette: Sendable {
    /// The screen.
    let void: Color
    /// Centre of the radial vignette behind the instrument.
    let plate: Color
    /// Machining marks, list leaders.
    let etch1: Color
    /// Engraved hairline: nested arcs to come, carriers, rules, empty slots.
    let etch2: Color
    /// Strong engraving: first-level arcs to come, ticks, inactive sigils.
    let etch3: Color
    /// Secondary text and the unit letters inside a reading.
    let ash: Color
    /// Numerals and names; beads of completed children.
    let bone: Color
    /// The one cold light: elapsed first-level arcs, focus marks.
    let lumen: Color
    /// Lumen at rest: elapsed nested arcs, the lit part of a counter slot.
    let lumenMid: Color
    /// Elapsed part of a carrier; completed slots on minor counter rings.
    let lumenDim: Color
    /// Completed slots on major counter rings.
    let lumenEtch: Color
    /// The lit part of the current slot on a major counter ring.
    let lumenMajor: Color
    /// The point of now and the next threshold.
    let now: Color
    /// The core of the point of now.
    let nowCore: Color
    /// The Sun: sync odometer, sync ring, Pentad mark. Nothing else.
    let sol: Color
    /// The Sun, completed or inactive.
    let solDim: Color
    /// Engraved labels of the Sun's block.
    let solLabel: Color
    /// Empty slots of the Sun's ring.
    let solEmpty: Color
    /// Rung ζ1 (656 nm) only.
    let hAlpha: Color
    /// Every Earth translation.
    let earth: Color
    /// Limb letters of levels that are not units.
    let between: Color
    /// Letters on the major counter rings.
    let majorLabel: Color
    /// Major names that are not the finest one, in the desktop column.
    let majorName: Color
    /// A level's seal where levels are listed (ladder rows, the lens's lineage).
    let seal: Color
    /// Names in a list that are not the leading one (the lens's media).
    let listText: Color
}

/// The faces (DESIGN.md §3): a reading face for numerals and Greek, an
/// engraved face for capitals, and the face of the Earth translations.
struct Typography: Sendable {
    let reading: Typeface
    let engraved: Typeface
    let earth: Typeface
    /// Weight of the big reading. The design says "Ultralight 200" in CSS
    /// terms; on the system face CSS 200 is the weight Apple calls Thin
    /// (CSS 100 is Apple's Ultralight), and Thin is what the renders show.
    let readingWeight: Font.Weight
    /// Weight of values, countdowns and the reading's trailing terms (Light 300).
    let valueWeight: Font.Weight
    /// Weight of Earth translations (Regular 400).
    let earthWeight: Font.Weight
    /// Tracking of engraved words, in em (0.24), and of the date line (0.30).
    let engravedTracking: CGFloat
    let dateTracking: CGFloat
    /// Whether the engraved face has Greek letters. When it has not, a level
    /// letter inside an engraved run is set in the reading face.
    let engravedHasGreek: Bool
}

/// One face: the system font, or a named one that every Apple platform ships.
enum Typeface: Sendable {
    case system
    case named(String)

    /// The font at a fixed size: engraved instrument text does not follow
    /// Dynamic Type (the layout is a drawing, not a flow of text).
    func font(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        switch self {
        case .system:
            return SystemFace.font(size: size, weight: weight)
        case .named(let name):
            return .custom(name, fixedSize: size)
        }
    }
}

/// Line weights in points (DESIGN.md §4). All caps and joins are round.
struct LineWeights: Sendable {
    /// Machining marks, the alidade.
    let hairline: CGFloat
    /// Carriers, rules, nested arcs, engraving.
    let engraving: CGFloat
    /// The elapsed part of a carrier.
    let carrierLit: CGFloat
    /// Counter rings of the major periods / of the minor ones.
    let counterMajor: CGFloat
    let counterMinor: CGFloat
    /// The lit part of the current slot is this much heavier.
    let currentSlotFactor: CGFloat
    /// Ticks and graduations.
    let tick: CGFloat
    /// Sigils and marks of the interface.
    let sigil: CGFloat
    /// The hero line: first-level arcs of the focused ring.
    let heroPhone: CGFloat
    let heroDesktop: CGFloat
    /// First-level arcs still to come.
    let heroToCome: CGFloat
    /// Nested arcs by depth below the hero: grandchildren, great-grandchildren, deeper.
    let nested: [CGFloat]
    /// Opacity of elapsed nested arcs, same order.
    let nestedOpacity: [Double]
}

/// The glow (DESIGN.md §2): one Gaussian blur of the same path under the
/// crisp stroke. An opacity of 0 switches that glow off.
struct Glow: Sendable {
    /// Blur sigma in points.
    let radiusPhone: CGFloat
    let radiusDesktop: CGFloat
    /// First-level elapsed arcs.
    let arc: Double
    /// Phase glyphs.
    let glyph: Double
    /// The point of now.
    let now: Double
    /// Planets on the counter rings.
    let planet: Double
}

// MARK: - Environment

private struct ThemeKey: EnvironmentKey {
    static let defaultValue = Theme.astrolabe
}

extension EnvironmentValues {
    /// The token table in force. Set once at the root from `AppModel.theme`.
    var theme: Theme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}

// MARK: - Colour from a hex token

extension Color {
    /// A colour from a design token written as `0xRRGGBB` (sRGB). Used only
    /// by the theme files: this is how a token table spells a colour.
    init(token hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}
