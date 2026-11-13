import SwiftUI
import CoreText
#if canImport(UIKit)
import UIKit
private typealias PlatformFont = UIFont
#else
import AppKit
private typealias PlatformFont = NSFont
#endif

/// The system face (SF Pro) as the design draws it: with the optical size
/// held at the display end at every point size, and tabular figures.
///
/// Why not plain `Font.system(size:)`: below 20 pt the system picks the
/// "text" optical size, whose letters are wider and more loosely fitted. The
/// design's renders use the display cut throughout, so the small Earth lines
/// (9 – 11.5 pt) would come out a tenth wider than drawn, and the values a
/// few per cent. Holding the `opsz` axis reproduces the design's widths; the
/// weight and every other trait stay the system's own.
enum SystemFace {
    /// The `opsz` variation axis, and its display end.
    private static let opticalSizeAxis = 0x6F70_737A   // 'opsz'
    private static let displayOpticalSize: CGFloat = 28

    static func font(size: CGFloat, weight: Font.Weight) -> Font {
        cache.font(size: size, weight: weight) { make(size: size, weight: weight) }
    }

    private static func make(size: CGFloat, weight: Font.Weight) -> Font {
        let base = PlatformFont.systemFont(ofSize: size, weight: platformWeight(weight)) as CTFont
        // The variation has to be given as an attribute dictionary: the
        // system font ignores CTFontDescriptorCreateCopyWithVariation.
        let attributes: [CFString: Any] = [
            kCTFontVariationAttribute: [opticalSizeAxis: displayOpticalSize],
            // Tabular figures: a reading must not shift as its digits change.
            kCTFontFeatureSettingsAttribute: [[
                kCTFontFeatureTypeIdentifierKey: kNumberSpacingType,
                kCTFontFeatureSelectorIdentifierKey: kMonospacedNumbersSelector,
            ]],
        ]
        let descriptor = CTFontDescriptorCreateCopyWithAttributes(CTFontCopyFontDescriptor(base), attributes as CFDictionary)
        return Font(CTFontCreateWithFontDescriptor(descriptor, size, nil))
    }

    /// Building a font from a descriptor makes Core Text match it against
    /// the installed faces, which is far too slow to do for every text of
    /// every frame: each (size, weight) is built once.
    private static let cache = FontCache()

    private static func platformWeight(_ weight: Font.Weight) -> PlatformFont.Weight {
        switch weight {
        case .ultraLight: return .ultraLight
        case .thin: return .thin
        case .light: return .light
        case .medium: return .medium
        case .semibold: return .semibold
        case .bold: return .bold
        default: return .regular
        }
    }
}

/// A small lock-protected memo of the fonts made by ``SystemFace``. Renderers
/// are not tied to an actor, so the cache guards itself.
private final class FontCache: @unchecked Sendable {
    private struct Key: Hashable {
        let size: CGFloat
        let weight: Font.Weight
    }

    private let lock = NSLock()
    private var fonts: [Key: Font] = [:]

    func font(size: CGFloat, weight: Font.Weight, make: () -> Font) -> Font {
        let key = Key(size: size, weight: weight)
        lock.lock()
        defer { lock.unlock() }
        if let font = fonts[key] { return font }
        let font = make()
        fonts[key] = font
        return font
    }
}
