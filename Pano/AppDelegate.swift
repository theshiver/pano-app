import AppKit
import PanoCore
import PanoStore
import PanoUI
import SwiftUI

/// Wires the pieces together on launch: opens the store, starts the capture loop, builds the
/// panel, and binds the global hotkey that toggles it.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var store: Store?
    private var engine: CaptureEngine?
    private var panel: PanelController?
    private var model: PanelModel?
    private var hotKey: GlobalHotKey?
    private var statusItem: NSStatusItem?
    private var onboarding: OnboardingController?
    private var settings: SettingsController?
    private var prefs: Preferences?
    private var isPaused = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        let store: Store
        do {
            store = try Store(folder: Self.storeFolder())
        } catch {
            NSLog("Pano: failed to open store: \(error)")
            return
        }
        self.store = store

        let prefs = Preferences()
        self.prefs = prefs
        Task { await store.setRetention(prefs.retentionRules) }

        let engine = CaptureEngine(store: store)
        self.engine = engine
        Task {
            await engine.setExcludedBundleIds((try? await store.excludedBundleIds()) ?? [])
            await engine.start()
        }

        let panel = PanelController(prefs: prefs)
        self.panel = panel

        let actions = PanelActions(
            paste: { [weak panel] id, plainText in
                // Order matters (docs/adr/0003): hide the panel first so the previous app regains
                // key focus, let it settle, then write the payload and post ⌘V. Doing these in one
                // Task guarantees the sequence; two separate Tasks raced and ⌘V hit Pano itself.
                Task { @MainActor in
                    panel?.hide()
                    try? await Task.sleep(for: .milliseconds(60))
                    var payload = (try? await store.payload(of: id)) ?? []
                    if plainText, let plain = payload.first(where: { $0.uti == "public.utf8-plain-text" }) {
                        payload = [plain]  // ⇧⏎: paste without formatting
                    }
                    await PasteService.paste(payload)
                }
            },
            pasteText: { [weak panel] text in
                Task { @MainActor in
                    panel?.hide()
                    try? await Task.sleep(for: .milliseconds(60))
                    await PasteService.paste([("public.utf8-plain-text", Data(text.utf8))])
                }
            },
            close: { [weak panel] in
                Task { @MainActor in panel?.hide() }
            }
        )
        let model = PanelModel(store: store, actions: actions)
        self.model = model
        panel.setContent(PanelView(model: model), model: model)

        installHotKey()

        setUpStatusItem()

        let onboarding = OnboardingController()
        self.onboarding = onboarding
        onboarding.showIfNeeded()

        settings = SettingsController(
            prefs: prefs, store: store,
            onHotKeyChanged: { [weak self] in self?.installHotKey() },
            onExclusionsChanged: { [weak self] in self?.reloadExclusions() }
        )
    }

    /// (Re)registers the global hotkey from the current preference. Reassigning the property lets
    /// the old GlobalHotKey deinit unregister itself first.
    private func reloadExclusions() {
        guard let store, let engine else { return }
        Task { await engine.setExcludedBundleIds((try? await store.excludedBundleIds()) ?? []) }
    }

    private func installHotKey() {
        guard let prefs else { return }
        hotKey = GlobalHotKey(keyCode: prefs.hotKeyCode, modifiers: prefs.hotKeyModifiers) { [weak self] in
            Task { @MainActor in self?.toggle() }
        }
    }

    // MARK: Menu bar

    /// The menu-bar item is the only always-visible control: pause/resume capture, clear history,
    /// open the panel, and quit — the app is an accessory (LSUIElement) with no Dock icon, so
    /// without this there is no way to quit it.
    private func setUpStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(
            systemSymbolName: "doc.on.clipboard",
            accessibilityDescription: "Pano"
        )
        item.menu = buildMenu()
        statusItem = item
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(
            withTitle: String(localized: "Open Pano"),
            action: #selector(openPanel),
            keyEquivalent: ""
        ).target = self

        let pauseTitle = isPaused ? String(localized: "Resume Pano") : String(localized: "Pause Pano")
        menu.addItem(withTitle: pauseTitle, action: #selector(togglePause), keyEquivalent: "").target = self

        menu.addItem(
            withTitle: String(localized: "Clear History…"),
            action: #selector(clearHistory),
            keyEquivalent: ""
        ).target = self

        menu.addItem(
            withTitle: String(localized: "Settings…"),
            action: #selector(openSettings),
            keyEquivalent: ","
        ).target = self

        menu.addItem(.separator())
        menu.addItem(
            withTitle: String(localized: "Quit Pano"),
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        return menu
    }

    @objc private func openPanel() {
        guard let panel, !panel.isVisible else { return }
        toggle()
    }

    @objc private func openSettings() {
        settings?.show()
    }

    @objc private func togglePause() {
        isPaused.toggle()
        let paused = isPaused
        Task { await engine?.setPaused(paused) }
        statusItem?.menu = buildMenu()
        statusItem?.button?.appearsDisabled = paused
    }

    @objc private func clearHistory() {
        let alert = NSAlert()
        alert.messageText = String(localized: "Clear clipboard history?")
        alert.informativeText = String(
            localized: "This deletes all unpinned items. Pinned items are kept. This cannot be undone."
        )
        alert.alertStyle = .warning
        alert.addButton(withTitle: String(localized: "Clear"))
        alert.addButton(withTitle: String(localized: "Cancel"))
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        Task { @MainActor in
            try? await store?.clearHistory()
            model?.reload()
        }
    }

    /// Opening the panel first runs one capture tick so the item the user just copied is present
    /// even if the 0.5 s poll has not fired yet, then reloads and shows.
    private func toggle() {
        guard let panel else { return }
        if panel.isVisible {
            panel.hide()
            return
        }
        Task { @MainActor in
            await engine?.tick()
            model?.activate()
            panel.show()
        }
    }

    private static func storeFolder() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Pano", isDirectory: true)
    }
}
