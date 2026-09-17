import Foundation

/// What the panel needs the app target to do. The panel is pure SwiftUI; the AppKit side
/// (paste-back, closing the non-activating window) is injected so PanoUI stays testable and
/// free of app-target dependencies. Pin and delete go straight to the store from the model.
public struct PanelActions: Sendable {
    /// Paste the clip. `plainText` strips formatting by writing only the plain-text representation.
    public var paste: @Sendable (_ id: Int64, _ plainText: Bool) -> Void
    public var close: @Sendable () -> Void

    public init(
        paste: @escaping @Sendable (_ id: Int64, _ plainText: Bool) -> Void,
        close: @escaping @Sendable () -> Void
    ) {
        self.paste = paste
        self.close = close
    }
}
