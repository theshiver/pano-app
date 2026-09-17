import Foundation

/// What the panel needs the app target to do. The panel is pure SwiftUI; the AppKit side
/// (paste-back, closing the non-activating window) is injected so PanoUI stays testable and
/// free of app-target dependencies.
public struct PanelActions: Sendable {
    public var paste: @Sendable (Int64) -> Void
    public var close: @Sendable () -> Void

    public init(paste: @escaping @Sendable (Int64) -> Void, close: @escaping @Sendable () -> Void) {
        self.paste = paste
        self.close = close
    }
}
