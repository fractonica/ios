import SwiftUI
import ImageIO
import UniformTypeIdentifiers
import FractonicaKit

/// Snapshot mode: `--snapshot <directory>` renders every screen × mode ×
/// layout at a pinned instant to PNG files, without opening a window, and
/// exits (Tools/snapshot.sh). The pictures are what the app draws: the same
/// `RootView`, the same model, rendered by `ImageRenderer`.
///
///     <screen>-<layout>-<mode>.png           now | ladder | lens | wave × phone | desktop × pure | earth
///     now-phone-pure-focus<L>.png            the focus sweep, L = 0 3 5 6 7 9 12 13
///     ladder-<layout>-<mode>-rung<L>.png     the wheel at the top, the Helion, ζ1 and the bottom: L = 0 6 29 62
///     lens-<layout>-<mode>-rung<L>.png       the lens on L = 0 6 12 13 29 30 62
///     wave-<layout>-<mode>-focus<L>.png      the wave re-scaled to L = 3 6 9
///     wave-<layout>-<mode>-scrubbed.png      the cursor away from now: the offset on the NOW mark
///     <screen>-<layout>-<mode>-scrubbed.png  now, ladder and lens showing that same scrubbed moment
///
/// With `--size <W>x<H>` the set is instead the four screens in both modes at
/// that view size (`<screen>-<W>x<H>-<mode>.png`, at 2x): how the design fits
/// a window or a device of another shape.
///
/// Phone pictures are 393 × 852 at 3x, desktop ones 1280 × 800 at 2x. The
/// instant is `--t` (default: SPEC vector A); `--focus`, `--theme` and
/// `--zone` apply to every picture. A new `Screen` case is rendered without
/// any change here.
@MainActor
enum SnapshotRunner {
    /// SPEC test vector A: 2026-10-08T12:00:00Z.
    static let vectorA: Int64 = 1_791_460_800

    /// The focus levels of the sweep.
    static let focusSweep = [0, 3, 5, 6, 7, 9, 12, 13]

    /// The rungs the ladder is turned to: the top, the Helion, ζ1 (visible
    /// light) and the bottom.
    static let ladderRungs = [0, 6, 29, 62]

    /// The rungs the lens is shown on: the Alpha, the Helion, the Blink, the
    /// first rung under it (the last with a live ring), ζ1, η1 and the last.
    static let lensRungs = [0, 6, 12, 13, 29, 30, 62]

    /// The focus levels the wave is re-scaled to: the Delta, the Helion, κ.
    static let waveFocus = [3, 6, 9]

    /// How far the scrubbed pictures are from the pinned instant, in seconds
    /// of the snapshot's own bookkeeping (never shown): some Helions ahead,
    /// so that the NOW mark reads a two-part span.
    static let scrubbedOffset: Int64 = 60_630

    /// Renders everything into `directory`. Returns the process exit code.
    static func run(_ arguments: LaunchArguments, directory: String) -> Int32 {
        let folder = URL(fileURLWithPath: directory, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        } catch {
            print("snapshot: cannot create \(folder.path): \(error.localizedDescription)")
            return 1
        }
        var pinned = arguments
        pinned.snapshotDirectory = nil
        if pinned.frozenInstant == nil { pinned.frozenInstant = Instant(unixSeconds: vectorA) }

        var failures = 0
        if let size = pinned.size {
            // A size of the caller's own: every screen in both modes, fitted
            // into that view as a window or a device of that size fits it.
            for screen in Screen.allCases {
                for mode in DisplayMode.allCases {
                    var shot = pinned
                    shot.screen = screen
                    shot.mode = mode
                    let name = "\(screen.rawValue)-\(Int(size.width))x\(Int(size.height))-\(mode.rawValue).png"
                    if !render(shot, to: folder.appendingPathComponent(name)) { failures += 1 }
                }
            }
            return failures == 0 ? 0 : 1
        }
        for layout in LayoutClass.allCases {
            for screen in Screen.allCases {
                for mode in DisplayMode.allCases {
                    var shot = pinned
                    shot.layout = layout
                    shot.screen = screen
                    shot.mode = mode
                    let name = "\(screen.rawValue)-\(layout.rawValue)-\(mode.rawValue).png"
                    if !render(shot, to: folder.appendingPathComponent(name)) { failures += 1 }
                }
            }
        }
        for level in focusSweep {
            var shot = pinned
            shot.layout = .phone
            shot.screen = .now
            shot.mode = .pure
            shot.focus = Level(level)
            if !render(shot, to: folder.appendingPathComponent("now-phone-pure-focus\(level).png")) { failures += 1 }
        }
        for (screen, rungs) in [(Screen.ladder, ladderRungs), (Screen.lens, lensRungs)] {
            for layout in LayoutClass.allCases {
                for mode in DisplayMode.allCases {
                    for rung in rungs {
                        var shot = pinned
                        shot.layout = layout
                        shot.screen = screen
                        shot.mode = mode
                        shot.rung = Level(rung)
                        let name = "\(screen.rawValue)-\(layout.rawValue)-\(mode.rawValue)-rung\(rung).png"
                        if !render(shot, to: folder.appendingPathComponent(name)) { failures += 1 }
                    }
                }
            }
        }
        for layout in LayoutClass.allCases {
            for mode in DisplayMode.allCases {
                for level in waveFocus {
                    var shot = pinned
                    shot.layout = layout
                    shot.screen = .wave
                    shot.mode = mode
                    shot.focus = Level(level)
                    let name = "wave-\(layout.rawValue)-\(mode.rawValue)-focus\(level).png"
                    if !render(shot, to: folder.appendingPathComponent(name)) { failures += 1 }
                }
                // Time travel is global: every screen shows the scrubbed moment.
                for screen in Screen.allCases {
                    var shot = pinned
                    shot.layout = layout
                    shot.screen = screen
                    shot.mode = mode
                    shot.cursor = pinned.frozenInstant.map {
                        $0.advanced(byMicroseconds: scrubbedOffset * 1_000_000)
                    }
                    let name = "\(screen.rawValue)-\(layout.rawValue)-\(mode.rawValue)-scrubbed.png"
                    if !render(shot, to: folder.appendingPathComponent(name)) { failures += 1 }
                }
            }
        }
        return failures == 0 ? 0 : 1
    }

    /// Draws the view into a bitmap of our own, in sRGB and with font
    /// smoothing off: text is then rasterised as a device draws it, not with
    /// the heavier stems a Mac bitmap context adds by default.
    /// - Parameter opaque: no alpha channel in the picture (an iOS app icon
    ///   must have none).
    static func rasterize<Content: View>(
        _ renderer: ImageRenderer<Content>, size: CGSize, scale: CGFloat, opaque: Bool = false
    ) -> CGImage? {
        let alpha: CGImageAlphaInfo = opaque ? .noneSkipLast : .premultipliedLast
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                  data: nil, width: Int(size.width * scale), height: Int(size.height * scale),
                  bitsPerComponent: 8, bytesPerRow: 0, space: space, bitmapInfo: alpha.rawValue
              )
        else { return nil }
        context.setAllowsFontSmoothing(false)
        context.setShouldSmoothFonts(false)
        context.scaleBy(x: scale, y: scale)
        renderer.render(rasterizationScale: scale) { _, draw in
            draw(context)
        }
        return context.makeImage()
    }

    /// The pixel scale of a layout's picture.
    static func scale(of layout: LayoutClass) -> CGFloat {
        layout == .phone ? 3 : 2
    }

    /// Renders one pinned state to one PNG file.
    @discardableResult
    static func render(_ arguments: LaunchArguments, to url: URL) -> Bool {
        // A size of the caller's own is fitted as a window of that size is;
        // otherwise the picture is the design's own size.
        let layout = arguments.layout ?? arguments.size.map(LayoutClass.fitting) ?? .phone
        let model = AppModel(arguments: arguments)
        model.layout = layout
        let size = arguments.size ?? layout.designSize
        let scale = arguments.size == nil ? scale(of: layout) : 2
        let content = RootView()
            .environment(model)
            .environment(\.displayScale, scale)
            .frame(width: size.width, height: size.height)
        let renderer = ImageRenderer(content: content)
        renderer.proposedSize = ProposedViewSize(size)
        guard let image = rasterize(renderer, size: size, scale: scale) else {
            print("snapshot: could not render \(url.lastPathComponent)")
            return false
        }
        return write(image, to: url)
    }

    /// Writes a picture as a PNG file and says so.
    static func write(_ image: CGImage, to url: URL) -> Bool {
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
        else {
            print("snapshot: could not write \(url.path)")
            return false
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            print("snapshot: could not write \(url.path)")
            return false
        }
        print("snapshot: \(url.lastPathComponent)  \(image.width) x \(image.height)")
        return true
    }
}
