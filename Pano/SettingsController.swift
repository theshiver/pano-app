import AppKit
import PanoStore
import PanoUI
import ServiceManagement
import SwiftUI

/// Owns the preferences window and applies the settings that have side effects: retention to the
/// store and launch-at-login through ServiceManagement. Plain values persist in `Preferences`.
@MainActor
final class SettingsController {
    private let prefs: Preferences
    private let store: Store
    private var window: NSWindow?

    init(prefs: Preferences, store: Store) {
        self.prefs = prefs
        self.store = store
    }

    func show() {
        let window =
            self.window
            ?? NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 420, height: 340),
                styleMask: [.titled, .closable], backing: .buffered, defer: false
            )
        window.title = String(localized: "Pano Settings")
        window.center()
        window.contentView = NSHostingView(
            rootView: SettingsView(
                prefs: prefs,
                onRetentionChanged: { [store, prefs] in
                    Task { await store.setRetention(prefs.retentionRules) }
                },
                onLaunchAtLoginChanged: { Self.setLaunchAtLogin($0) }
            )
        )
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
    }

    private static func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("Pano: launch-at-login \(enabled ? "register" : "unregister") failed: \(error)")
        }
    }
}
