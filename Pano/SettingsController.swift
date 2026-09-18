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
    private let onHotKeyChanged: () -> Void
    private let onExclusionsChanged: () -> Void
    private let onOCRChanged: (Bool) -> Void
    private let onMaskSecretsChanged: (Bool) -> Void
    private let onHighlightChanged: (Bool) -> Void
    private let onThemeChanged: (String) -> Void
    private var window: NSWindow?
    private var exclusion: ExclusionModel?

    init(
        prefs: Preferences, store: Store,
        onHotKeyChanged: @escaping () -> Void, onExclusionsChanged: @escaping () -> Void,
        onOCRChanged: @escaping (Bool) -> Void,
        onMaskSecretsChanged: @escaping (Bool) -> Void,
        onHighlightChanged: @escaping (Bool) -> Void,
        onThemeChanged: @escaping (String) -> Void
    ) {
        self.prefs = prefs
        self.store = store
        self.onHotKeyChanged = onHotKeyChanged
        self.onExclusionsChanged = onExclusionsChanged
        self.onOCRChanged = onOCRChanged
        self.onMaskSecretsChanged = onMaskSecretsChanged
        self.onHighlightChanged = onHighlightChanged
        self.onThemeChanged = onThemeChanged
    }

    func show() {
        // Reuse the window across opens. isReleasedWhenClosed must be false or closing it with the
        // red button deallocates it, leaving a dangling reference and no window on the next open.
        if let window {
            refreshExclusions()
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 460),
            styleMask: [.titled, .closable], backing: .buffered, defer: false
        )
        window.isReleasedWhenClosed = false
        window.title = String(localized: "Pano Settings")
        window.center()
        let exclusion = ExclusionModel(
            onAdd: { [weak self] in self?.pickAppToExclude() },
            onRemove: { [weak self] bundleId in self?.removeExcludedApp(bundleId) }
        )
        self.exclusion = exclusion
        refreshExclusions()

        window.contentView = NSHostingView(
            rootView: SettingsView(
                prefs: prefs,
                exclusion: exclusion,
                onRetentionChanged: { [store, prefs] in
                    Task { await store.setRetention(prefs.retentionRules) }
                },
                onLaunchAtLoginChanged: { Self.setLaunchAtLogin($0) },
                onHotKeyChanged: onHotKeyChanged,
                onOCRChanged: onOCRChanged,
                onMaskSecretsChanged: onMaskSecretsChanged,
                onHighlightChanged: onHighlightChanged,
                onThemeChanged: onThemeChanged
            )
        )
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
    }

    private func refreshExclusions() {
        Task { @MainActor in
            let apps = (try? await store.excludedApps()) ?? []
            exclusion?.apps = apps
        }
    }

    /// Lets the user pick an app to exclude. An NSOpenPanel restricted to applications gives us
    /// sandbox-legal read access to the bundle, from which we read its identifier and name.
    private func pickAppToExclude() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = String(localized: "Exclude")
        guard panel.runModal() == .OK, let url = panel.url,
            let bundle = Bundle(url: url), let bundleId = bundle.bundleIdentifier
        else { return }
        let name = FileManager.default.displayName(atPath: url.path)
        Task { @MainActor in
            try? await store.addExcludedApp(bundleId: bundleId, displayName: name)
            refreshExclusions()
            onExclusionsChanged()
        }
    }

    private func removeExcludedApp(_ bundleId: String) {
        Task { @MainActor in
            try? await store.removeExcludedApp(bundleId: bundleId)
            refreshExclusions()
            onExclusionsChanged()
        }
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
