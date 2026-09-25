import AppKit
import PanoUI
import SwiftUI

/// The first-run window: teaches ⌘⇧V and gets out of the way. Shown once per install and never a
/// permission gate: it asks macOS for nothing and does not mention auto-paste, which is offered in
/// context after the first ⏎ instead (docs/adr/0003, second addendum).
@MainActor
final class OnboardingController {
    private let prefs: Preferences
    private var window: NSWindow?

    init(prefs: Preferences) { self.prefs = prefs }

    /// The window is shown once per install and the flag lives in the app's sandbox container, which
    /// is TCC-protected — so on a dev machine there is no way to get a first run back from outside
    /// the app. `PANO_FORCE_ONBOARDING=1` (Debug builds) shows it anyway, without writing the flag.
    private var forceOnboarding: Bool {
        #if DEBUG
            return ProcessInfo.processInfo.environment["PANO_FORCE_ONBOARDING"] == "1"
        #else
            return false
        #endif
    }

    /// Shows the window once per install, whatever the permission state.
    @discardableResult
    func showIfNeeded() -> Bool {
        if forceOnboarding {
            show()
            return true
        }
        guard !prefs.hasSeenOnboarding else { return false }
        prefs.hasSeenOnboarding = true
        show()
        return true
    }

    func show() {
        let window =
            self.window
            ?? NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: OnboardingView.width, height: 520),
                styleMask: [.titled, .closable, .fullSizeContentView],
                backing: .buffered, defer: false
            )
        window.isReleasedWhenClosed = false
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        let hosting = NSHostingView(rootView: OnboardingView(onDone: { [weak self] in self?.close() }))
        // `.intrinsicContentSize` too, or `fittingSize` below is `.zero` (see PasteHintController).
        hosting.sizingOptions = [.preferredContentSize, .intrinsicContentSize]
        window.contentView = hosting
        window.setContentSize(hosting.fittingSize)
        window.center()
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
    }

    private func close() {
        window?.close()
        window = nil
    }
}
