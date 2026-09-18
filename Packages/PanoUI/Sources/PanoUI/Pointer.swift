import AppKit
import SwiftUI

extension View {
    /// Shows the pointing-hand cursor while hovering, so clickable custom views (rows, chips, rail
    /// icons) read as clickable. Native controls in Settings already do this themselves.
    func pointer() -> some View {
        onHover { inside in
            if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
    }
}
