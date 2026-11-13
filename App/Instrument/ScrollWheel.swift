import SwiftUI

/// One scroll of the Mac's wheel or trackpad, as a screen wants it.
struct ScrollInput {
    /// Whole steps along the scale: +1 finer (wheel up, fingers up), −1
    /// coarser. Zero when the scroll was a sideways one.
    var steps = 0
    /// A sideways two-finger swipe (or a shift-turned wheel): points of
    /// travel, positive when the fingers move right (the content follows
    /// them). Zero when the scroll was an up-and-down one.
    var pan: CGFloat = 0
    /// Where the pointer was: a point in the window's content, origin top
    /// left (the root view fills the window, so convert it with
    /// `DesignSpace.designPoint`). `nil` when the event had no window.
    var location: CGPoint?
}

extension View {
    /// Calls `onStep` with +1 (finer) or −1 (coarser) as the scroll wheel or
    /// the trackpad turns the limb (DESIGN.md §8). On the Mac only; a no-op
    /// elsewhere. Both axes turn it: up, or fingers to the left, is finer.
    /// Attach it to a screen that shows a limb: it listens while that screen
    /// is on.
    func onScrollWheelStep(_ onStep: @escaping (Int) -> Void) -> some View {
        #if os(macOS)
        return modifier(ScrollWheelSteps(axes: .combined) { input in
            if input.steps != 0 { onStep(input.steps) }
        })
        #else
        return self
        #endif
    }

    /// The two axes apart, with the pointer's place: an up-and-down scroll
    /// arrives as ``ScrollInput/steps``, a sideways one as
    /// ``ScrollInput/pan`` (a timeline moves through time sideways and
    /// changes its scale up and down).
    func onScrollWheel(_ onInput: @escaping (ScrollInput) -> Void) -> some View {
        #if os(macOS)
        return modifier(ScrollWheelSteps(axes: .split, onInput: onInput))
        #else
        return self
        #endif
    }
}

#if os(macOS)
import AppKit

/// Turns scroll events into whole steps and sideways travel: a wheel click
/// is one step, a trackpad swipe one step per 36 points. Momentum after the
/// fingers lift is ignored so that a flick does not run through the whole
/// ladder.
///
/// The event monitor is installed once, but the handler it calls is the one
/// from the LATEST evaluation of the view (kept in a reference that every
/// evaluation refreshes): a handler captures the view's environment (the
/// design space of the window's current size), and an old one would map the
/// pointer with an old scale after the window is resized.
private struct ScrollWheelSteps: ViewModifier {
    enum Axes {
        /// Both axes are one value (a limb).
        case combined
        /// The dominant axis of each event decides: vertical steps, sideways pan.
        case split
    }

    /// The latest handler, read by the monitor at each event.
    @MainActor
    private final class Latest {
        var onInput: (ScrollInput) -> Void = { _ in }
    }

    let axes: Axes
    let onInput: (ScrollInput) -> Void
    @State private var latest = Latest()
    @State private var monitor: Any?
    @State private var travelled: CGFloat = 0

    private static let pointsPerStep: CGFloat = 36

    func body(content: Content) -> some View {
        latest.onInput = onInput
        return content
            .onAppear {
                guard monitor == nil else { return }
                let latest = latest
                monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
                    handle(event, latest: latest)
                    return event
                }
            }
            .onDisappear {
                if let monitor { NSEvent.removeMonitor(monitor) }
                monitor = nil
            }
    }

    private func handle(_ event: NSEvent, latest: Latest) {
        guard event.momentumPhase.isEmpty else { return }
        if event.phase == .began { travelled = 0 }
        let location = event.window?.contentView.map { content in
            // AppKit measures from the bottom left of the window's content.
            CGPoint(x: event.locationInWindow.x, y: content.bounds.height - event.locationInWindow.y)
        }
        let dx = event.scrollingDeltaX, dy = event.scrollingDeltaY
        if axes == .split, abs(dx) > abs(dy) {
            // Sideways: travel in points (a wheel's click counts as one step's worth).
            let pan = event.hasPreciseScrollingDeltas ? dx : (dx > 0 ? 1 : -1) * ScrollWheelSteps.pointsPerStep
            latest.onInput(ScrollInput(pan: pan, location: location))
            return
        }
        // Up, or (combined) fingers to the left, is finer: the limb's letters follow the hand.
        let delta = axes == .split ? dy : dy - dx
        guard delta != 0 else { return }
        var steps = 0
        if event.hasPreciseScrollingDeltas {
            travelled += delta
            steps = Int(travelled / ScrollWheelSteps.pointsPerStep)
            travelled -= CGFloat(steps) * ScrollWheelSteps.pointsPerStep
        } else {
            steps = delta > 0 ? 1 : -1
        }
        if steps != 0 { latest.onInput(ScrollInput(steps: steps, location: location)) }
    }
}
#endif
