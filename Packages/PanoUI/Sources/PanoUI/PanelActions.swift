import Foundation

/// What the panel needs the app target to do. The panel is pure SwiftUI; the AppKit side
/// (paste-back, closing the non-activating window) is injected so PanoUI stays testable and
/// free of app-target dependencies. Pin and delete go straight to the store from the model.
public struct PanelActions: Sendable {
    /// Paste the clip. `plainText` strips formatting by writing only the plain-text representation.
    public var paste: @Sendable (_ id: Int64, _ plainText: Bool) -> Void
    /// Pastes a literal string (transformed values, colour formats). With `html`, the rich
    /// representation is written alongside so Mail/Notes/Slack keep the formatting.
    public var pasteText: @Sendable (_ text: String, _ html: String?) -> Void
    public var close: @Sendable () -> Void
    /// Opens the Settings window (the panel's ⚙︎; the only route when the menu-bar icon is hidden).
    public var openSettings: @Sendable () -> Void
    public var openUpdates: @Sendable () -> Void

    public init(
        paste: @escaping @Sendable (_ id: Int64, _ plainText: Bool) -> Void,
        pasteText: @escaping @Sendable (_ text: String, _ html: String?) -> Void,
        close: @escaping @Sendable () -> Void,
        openSettings: @escaping @Sendable () -> Void = {},
        openUpdates: @escaping @Sendable () -> Void = {}
    ) {
        self.paste = paste
        self.pasteText = pasteText
        self.close = close
        self.openSettings = openSettings
        self.openUpdates = openUpdates
    }
}
