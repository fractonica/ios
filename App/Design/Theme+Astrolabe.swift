import SwiftUI

extension Theme {
    /// Astrolabe: obsidian, engraved hairlines and one cold light
    /// (design/astrolabe/DESIGN.md §2–4). The default.
    static let astrolabe = Theme(
        name: "astrolabe",
        palette: Palette(
            void: Color(token: 0x040506),
            plate: Color(token: 0x0B0E12),
            etch1: Color(token: 0x12161B),
            etch2: Color(token: 0x262D36),
            etch3: Color(token: 0x48525E),
            ash: Color(token: 0x8D96A3),
            bone: Color(token: 0xE9ECF0),
            lumen: Color(token: 0x8DF3E9),
            lumenMid: Color(token: 0x4BB3AB),
            lumenDim: Color(token: 0x245A57),
            lumenEtch: Color(token: 0x1A4543),
            lumenMajor: Color(token: 0x35807A),
            now: Color(token: 0x8DF3E9),
            nowCore: Color(token: 0xFFFFFF),
            sol: Color(token: 0xFFD60A),
            solDim: Color(token: 0x7D6A12),
            solLabel: Color(token: 0xA08918),
            solEmpty: Color(token: 0x2A2616),
            hAlpha: Color(token: 0xFF4A3A),
            earth: Color(token: 0x8D96A3),
            between: Color(token: 0x5B6572),
            majorLabel: Color(token: 0x6F7985),
            majorName: Color(token: 0xB9C0C9),
            seal: Color(token: 0x7A8491),
            listText: Color(token: 0xC4CAD2)
        ),
        type: Typography(
            reading: .system,
            engraved: .named("Futura-Medium"),
            earth: .system,
            readingWeight: .thin,
            valueWeight: .light,
            earthWeight: .regular,
            engravedTracking: 0.24,
            dateTracking: 0.30,
            engravedHasGreek: true
        ),
        line: LineWeights(
            hairline: 0.5,
            engraving: 0.75,
            carrierLit: 0.9,
            counterMajor: 0.8,
            counterMinor: 1.0,
            currentSlotFactor: 1.2,
            tick: 0.8,
            sigil: 1.0,
            heroPhone: 1.4,
            heroDesktop: 1.7,
            heroToCome: 0.9,
            nested: [0.75, 0.6, 0.5],
            nestedOpacity: [0.95, 0.6, 0.5]
        ),
        glow: Glow(radiusPhone: 2.4, radiusDesktop: 3.2, arc: 0.42, glyph: 0.35, now: 0.9, planet: 0.5)
    )
}
