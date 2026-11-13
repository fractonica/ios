import SwiftUI
import FractonicaKit

extension AppModel {
    /// The focus as a binding, for controls that select a level (the limb).
    /// Writing goes through ``setFocus(_:)``, so it is clamped and persisted.
    var focusBinding: Binding<Level> {
        Binding(get: { self.focus }, set: { self.setFocus($0) })
    }

    /// The rung the lens inspects as a binding (any of the 63 levels).
    var lensLevelBinding: Binding<Level> {
        Binding(get: { self.lensLevel }, set: { self.setLensLevel($0) })
    }
}
