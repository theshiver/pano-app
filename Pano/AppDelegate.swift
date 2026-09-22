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
    private var pasteHint: PasteHintController?
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
        #if DEBUG
            if ProcessInfo.processInfo.environment["PANO_SEED"] == "1" { Task { try? await DemoSeed.run(store) } }
        #endif

        let prefs = Preferences()
        self.prefs = prefs
        Task { await store.setRetention(prefs.retentionRules) }

        let engine = CaptureEngine(store: store)
        self.engine = engine
        Task { [weak self] in
            await engine.setExcludedBundleIds((try? await store.excludedBundleIds()) ?? [])
            await engine.setOCREnabled(prefs.ocrEnabled)
            await engine.setMaskSecrets(prefs.maskSecrets)
            await engine.setOnChange { [weak self] in
                Task { @MainActor [weak self] in
                    guard let self, self.panel?.isVisible == true else { return }
                    self.model?.reload()
                }
            }
            await engine.start()
        }

        let panel = PanelController(prefs: prefs)
        self.panel = panel

        // Tells the user the clip is on the clipboard when ⏎ could not reach their app.
        let hint = PasteHintController(prefs: prefs)
        self.pasteHint = hint
        hint.showForDebugIfRequested()

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
                    let landed = await PasteService.paste(payload, auto: prefs.autoPaste)
                    if !landed { hint.showIfNeeded(trusted: PasteService.isAccessibilityTrusted) }
                }
            },
            pasteText: { [weak panel] text, html in
                Task { @MainActor in
                    panel?.hide()
                    try? await Task.sleep(for: .milliseconds(60))
                    var payload = [("public.utf8-plain-text", Data(text.utf8))]
                    if let html { payload.insert(("public.html", Data(html.utf8)), at: 0) }
                    let landed = await PasteService.paste(payload, auto: prefs.autoPaste)
                    if !landed { hint.showIfNeeded(trusted: PasteService.isAccessibilityTrusted) }
                }
            },
            close: { [weak panel] in
                Task { @MainActor in panel?.hide() }
            },
            openSettings: { [weak self] in
                Task { @MainActor in self?.openSettings() }
            }
        )
        let model = PanelModel(store: store, actions: actions)
        model.prefs = prefs
        model.onOCRChanged = { [weak self] enabled in Task { await self?.engine?.setOCREnabled(enabled) } }
        self.model = model
        panel.setContent(PanelView(model: model), model: model)

        installHotKey()

        setUpStatusItem(visible: prefs.showMenuBarIcon)

        // Off the launch path but on the main thread, which the importer requires. See its comment:
        // this is ~330 ms that would otherwise land on the first panel open.
        Task { @MainActor in RichPreview.prewarm() }

        let onboarding = OnboardingController(prefs: prefs)
        self.onboarding = onboarding
        onboarding.showIfNeeded()

        settings = SettingsController(
            prefs: prefs, store: store,
            onHotKeyChanged: { [weak self] in
                self?.installHotKey()
                self?.refreshStatusItem()  // the menu shows the shortcut
            },
            onExclusionsChanged: { [weak self] in self?.reloadExclusions() },
            onOCRChanged: { [weak self] enabled in
                Task { await self?.engine?.setOCREnabled(enabled) }
            },
            onMenuBarIconChanged: { [weak self] show in
                self?.setUpStatusItem(visible: show)
            },
            onMaskSecretsChanged: { [weak self] enabled in
                Task { await self?.engine?.setMaskSecrets(enabled) }
            },
            onHighlightChanged: { [weak self] _ in self?.model?.reload() },
            onThemeChanged: { [weak self] _ in self?.model?.reload() }
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

    /// The menu-bar item: open the panel, pause/resume capture, clear history, Settings, quit. The
    /// app is an accessory (LSUIElement) with no Dock icon, so this is the everyday entry point.
    /// It can be hidden in Settings; the panel's ⚙︎ then opens Settings, where ⌘Q still quits.
    private func setUpStatusItem(visible: Bool) {
        guard visible else {
            if let statusItem { NSStatusBar.system.removeStatusItem(statusItem) }
            statusItem = nil
            return
        }
        guard statusItem == nil else { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(named: "MenuBarIcon")
        item.button?.image?.accessibilityDescription = "Pano"
        item.menu = buildMenu()
        statusItem = item
        refreshStatusItem()
    }

    /// Paused capture dims the icon so the state is visible without opening the menu.
    private func refreshStatusItem() {
        statusItem?.button?.appearsDisabled = isPaused
        statusItem?.button?.toolTip = isPaused ? String(localized: "Pano — paused") : "Pano"
        statusItem?.menu = buildMenu()
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        let open = menu.addItem(
            withTitle: String(localized: "Open Pano"), action: #selector(openPanel), keyEquivalent: "")
        open.target = self
        open.keyEquivalentModifierMask = []
        open.title = String(localized: "Open Pano") + "\t" + (prefs?.hotKeyDisplay ?? "")

        let pause = menu.addItem(
            withTitle: String(localized: "Pause capture"), action: #selector(togglePause), keyEquivalent: "")
        pause.target = self
        pause.state = isPaused ? .on : .off

        menu.addItem(.separator())
        menu.addItem(withTitle: String(localized: "Clear History…"), action: #selector(clearHistory), keyEquivalent: "")
            .target = self
        menu.addItem(withTitle: String(localized: "Settings…"), action: #selector(openSettings), keyEquivalent: ",")
            .target = self

        menu.addItem(.separator())
        menu.addItem(
            withTitle: String(localized: "Quit Pano"), action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q")
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
        refreshStatusItem()
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
            _ = try? await store?.clearHistory()
            model?.reload()
        }
    }

    /// Shows the panel immediately with the current history, then runs one capture tick so the
    /// just-copied item shows up even if the 0.5 s poll has not fired yet. The tick can be slow
    /// (decoding a copied image file), so it must not block the panel from appearing.
    private func toggle() {
        guard let panel else { return }
        if panel.isVisible {
            panel.hide()
            return
        }
        model?.activate()
        panel.show()
        Task { @MainActor in
            if await engine?.tick() != nil { model?.reload() }
        }
    }

    /// `PANO_STORE_FOLDER` picks a sibling folder inside the container (demo data for screenshots,
    /// see DemoSeed.swift); the real history is never touched.
    private static func storeFolder() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let name = ProcessInfo.processInfo.environment["PANO_STORE_FOLDER"] ?? "Pano"
        return base.appendingPathComponent(name, isDirectory: true)
    }
}
