import SwiftUI

extension View {
    /// Shows the pointing-hand cursor while hovering, so anything clickable reads as clickable.
    ///
    /// Uses SwiftUI's own `pointerStyle` (macOS 15+) rather than pushing and popping `NSCursor` by
    /// hand: the manual stack leaks a stuck hand cursor whenever the matching exit event never
    /// arrives, which happens every time a window closes while the pointer is over a control.
    func pointer() -> some View {
        pointerStyle(.link)
    }
}
