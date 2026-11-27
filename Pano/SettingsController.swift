import AppKit
import PanoStore
import PanoUI
import ServiceManagement
import SwiftUI

@MainActor
final class SettingsController {
    private let prefs: Preferences
    private let store: Store
    private let supportsAutoPaste: Bool
    private let isAccessibilityTrusted: () -> Bool
    private let onOpenAccessibilitySettings: () -> Void
    private let onRevealAppInFinder: () -> Void
    private let onHotKeyChanged: () -> Void
    private let onExclusionsChanged: () -> Void
    private let onOCRChanged: (Bool) -> Void
    private let onMenuBarIconChanged: (Bool) -> Void
    private let onMaskSecretsChanged: (Bool) -> Void
    private let onHighlightChanged: (Bool) -> Void
    private let onThemeChanged: (String) -> Void
    private let onRetentionChanged: () -> Void
    private let onClearLastHour: () -> Void
    private let onClearAllHistory: () -> Void
    private let isCapturePaused: () -> Bool
    private let onToggleCapturePaused: (Bool) -> Void
    private var window: NSWindow?
    private var exclusion: ExclusionModel?

    init(
        prefs: Preferences,
        store: Store,
        supportsAutoPaste: Bool,
        isAccessibilityTrusted: @escaping () -> Bool,
        onOpenAccessibilitySettings: @escaping () -> Void,
        onRevealAppInFinder: @escaping () -> Void,
        onHotKeyChanged: @escaping () -> Void,
        onExclusionsChanged: @escaping () -> Void,
        onOCRChanged: @escaping (Bool) -> Void,
        onMenuBarIconChanged: @escaping (Bool) -> Void,
        onMaskSecretsChanged: @escaping (Bool) -> Void,
        onHighlightChanged: @escaping (Bool) -> Void,
        onThemeChanged: @escaping (String) -> Void,
        onRetentionChanged: @escaping () -> Void,
        onClearLastHour: @escaping () -> Void,
        onClearAllHistory: @escaping () -> Void,
        isCapturePaused: @escaping () -> Bool,
        onToggleCapturePaused: @escaping (Bool) -> Void
    ) {
        self.prefs = prefs
        self.store = store
        self.supportsAutoPaste = supportsAutoPaste
        self.isAccessibilityTrusted = isAccessibilityTrusted
        self.onOpenAccessibilitySettings = onOpenAccessibilitySettings
        self.onRevealAppInFinder = onRevealAppInFinder
        self.onHotKeyChanged = onHotKeyChanged
        self.onExclusionsChanged = onExclusionsChanged
        self.onOCRChanged = onOCRChanged
        self.onMenuBarIconChanged = onMenuBarIconChanged
        self.onMaskSecretsChanged = onMaskSecretsChanged
        self.onHighlightChanged = onHighlightChanged
        self.onThemeChanged = onThemeChanged
        self.onRetentionChanged = onRetentionChanged
        self.onClearLastHour = onClearLastHour
        self.onClearAllHistory = onClearAllHistory
        self.isCapturePaused = isCapturePaused
        self.onToggleCapturePaused = onToggleCapturePaused
    }

    func show() {
        if let window {
            refreshExclusions()
            activateWindow(window)
            return
        }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: supportsAutoPaste ? 540 : 470),
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
                supportsAutoPaste: supportsAutoPaste,
                isAccessibilityTrusted: isAccessibilityTrusted,
                onOpenAccessibilitySettings: onOpenAccessibilitySettings,
                onRevealAppInFinder: onRevealAppInFinder,
                onRetentionChanged: { [store, prefs, onRetentionChanged] in
                    Task {
                        await store.setRetention(prefs.retentionRules)
                        _ = try? await store.sweepExpired()
                        await MainActor.run { onRetentionChanged() }
                    }
                },
                onLaunchAtLoginChanged: { Self.setLaunchAtLogin($0) },
                onMenuBarIconChanged: onMenuBarIconChanged,
                onHotKeyChanged: onHotKeyChanged,
                onOCRChanged: onOCRChanged,
                onMaskSecretsChanged: onMaskSecretsChanged,
                onHighlightChanged: onHighlightChanged,
                onThemeChanged: onThemeChanged,
                onClearLastHour: onClearLastHour,
                onClearAllHistory: onClearAllHistory,
                isCapturePaused: isCapturePaused,
                onToggleCapturePaused: onToggleCapturePaused
            )
        )
        self.window = window
        activateWindow(window)
    }

    private func activateWindow(_ window: NSWindow) {
        NSRunningApplication.current.activate(options: [.activateAllWindows])
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
        DispatchQueue.main.async {
            NSApp.activate()
            window.makeKeyAndOrderFront(nil)
        }
    }

    private func refreshExclusions() {
        Task { @MainActor in
            let apps = (try? await store.excludedApps()) ?? []
            exclusion?.apps = apps
        }
    }

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
