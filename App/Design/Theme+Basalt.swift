import SwiftUI

extension Theme {
    /// Basalt: warm stone, bone engraving, serif (design/tablet/DESIGN.md §2–4).
    /// The same instrument in another palette and typeface: elapsed is carved
    /// bone, the present and the Sun are gold, Earth is verdigris.
    /// Selected with `--theme basalt`; there is no control for it yet.
    static let basalt = Theme(
        name: "basalt",
        palette: Palette(
            void: Color(token: 0x0B0907),       // basalt0
            plate: Color(token: 0x241E18),      // basalt2, the raking light
            etch1: Color(token: 0x1D1914),      // between basalt1 and seam: machining marks
            etch2: Color(token: 0x2E2821),      // seam
            etch3: Color(token: 0x6A5E4D),      // uncut
            ash: Color(token: 0x9D917B),        // dim
            bone: Color(token: 0xECE2CC),
            lumen: Color(token: 0xECE2CC),      // carved = bone
            lumenMid: Color(token: 0xC4BAA4),   // bone at about 80 % on the field
            lumenDim: Color(token: 0x857A67),   // faint
            lumenEtch: Color(token: 0x6A5E4D),  // uncut
            lumenMajor: Color(token: 0x9D917B), // dim
            now: Color(token: 0xE6B54E),        // gold: the present
            nowCore: Color(token: 0xFFF3D6),
            sol: Color(token: 0xE6B54E),        // gold: the Sun
            solDim: Color(token: 0x8A6C2F),
            solLabel: Color(token: 0xA9853A),
            solEmpty: Color(token: 0x2E2821),   // seam
            hAlpha: Color(token: 0xFF4A2E),
            earth: Color(token: 0x6CBCAA),      // verdigris
            between: Color(token: 0x857A67),    // faint
            majorLabel: Color(token: 0x857A67),
            majorName: Color(token: 0xC4BAA4),
            seal: Color(token: 0x857A67),       // faint
            listText: Color(token: 0xC4BAA4)
        ),
        type: Typography(
            reading: .named("IowanOldStyle-Roman"),
            engraved: .named("Optima-Regular"),
            earth: .named("IowanOldStyle-Italic"),
            readingWeight: .regular,
            valueWeight: .regular,
            earthWeight: .regular,
            engravedTracking: 0.26,
            dateTracking: 0.30,
            engravedHasGreek: false
        ),
        line: LineWeights(
            hairline: 0.5,
            engraving: 0.8,
            carrierLit: 1.0,
            counterMajor: 0.8,
            counterMinor: 1.0,
            currentSlotFactor: 1.3,
            tick: 0.9,
            sigil: 1.0,
            heroPhone: 2.1,
            heroDesktop: 2.4,
            heroToCome: 1.1,
            nested: [1.05, 0.7, 0.5],
            nestedOpacity: [0.9, 0.75, 0.6]
        ),
        // Only what is "now" glows on the tablet.
        glow: Glow(radiusPhone: 3.0, radiusDesktop: 3.6, arc: 0, glyph: 0, now: 0.9, planet: 0)
    )
}
