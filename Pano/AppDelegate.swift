import AppKit
import Carbon.HIToolbox
import PanoCore
import PanoStore
import PanoUI
import SwiftUI

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
    private var sweepTask: Task<Void, Never>?
    private var isPaused = false

    #if DIRECT_DISTRIBUTION
        private var updateService: UpdateService?
        private let supportsAutoPaste = true
    #else
        private let supportsAutoPaste = false
    #endif

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
        Task {
            await store.setRetention(prefs.retentionRules)
            _ = try? await store.sweepExpired()
        }
        startRetentionSweepLoop(store: store)

        let engine = CaptureEngine(store: store)
        self.engine = engine
        Task { [weak self] in
            await engine.setExcludedBundleIds((try? await store.excludedBundleIds()) ?? [])
            await engine.setOCREnabled(prefs.ocrEnabled)
            await engine.setMaskSecrets(prefs.maskSecrets)
            await engine.setOnChange { [weak self] in
                Task { @MainActor [weak self] in
                    guard let self, self.panel?.isVisible == true else { return }
                    self.model?.reload(refreshChrome: true)
                }
            }
            await engine.start()
        }

        let panel = PanelController(prefs: prefs)
        self.panel = panel

        let hint = PasteHintController(prefs: prefs)
        self.pasteHint = hint
        hint.showForDebugIfRequested()

        let actions = PanelActions(
            paste: { [weak self, weak panel] id, plainText in
                Task { @MainActor in
                    panel?.hide(animated: false)
                    var payload = (try? await store.payload(of: id)) ?? []
                    if plainText, let plain = payload.first(where: { $0.uti == "public.utf8-plain-text" }) {
                        payload = [plain]
                    }
                    await self?.deliverPaste(payload: payload, prefs: prefs, hint: hint)
                }
            },
            pasteText: { [weak self, weak panel] text, html in
                Task { @MainActor in
                    panel?.hide(animated: false)
                    var payload = [("public.utf8-plain-text", Data(text.utf8))]
                    if let html { payload.insert(("public.html", Data(html.utf8)), at: 0) }
                    await self?.deliverPaste(payload: payload, prefs: prefs, hint: hint)
                }
            },
            close: { [weak panel] in
                Task { @MainActor in panel?.hide() }
            },
            openSettings: { [weak self] in
                Task { @MainActor in self?.openSettings() }
            },
            openUpdates: { [weak self] in
                Task { @MainActor in self?.openUpdates() }
            }
        )
        #if DIRECT_DISTRIBUTION
            let updateService = UpdateService(prefs: prefs) { [weak self] in
                self?.refreshStatusItem()
            }
            self.updateService = updateService
            let currentUpdateModel: UpdateModel? = updateService.model
        #else
            let currentUpdateModel: UpdateModel? = nil
        #endif

        let model = PanelModel(store: store, actions: actions)
        model.prefs = prefs
        model.update = currentUpdateModel
        model.supportsAutoPaste = supportsAutoPaste
        model.searchDebounce = .milliseconds(35)
        #if DIRECT_DISTRIBUTION
            model.isAccessibilityTrusted = { AutoPasteService.isTrusted }
        #endif
        model.onOCRChanged = { [weak self] enabled in Task { await self?.engine?.setOCREnabled(enabled) } }
        self.model = model
        panel.setContent(PanelView(model: model), model: model)

        installHotKey()
        setUpStatusItem(visible: prefs.showMenuBarIcon)

        Task { @MainActor in RichPreview.prewarm() }

        let onboarding = OnboardingController(prefs: prefs, supportsAutoPaste: supportsAutoPaste) {
            [weak self] loadSamples, enableAutoPaste in
            #if DIRECT_DISTRIBUTION
                prefs.autoPaste = enableAutoPaste
            #endif
            if loadSamples {
                Task {
                    await StarterSeed.seedIfEmpty(store)
                    await MainActor.run { self?.model?.reload(selectTop: true, refreshChrome: true) }
                }
            }
        }
        self.onboarding = onboarding
        onboarding.showIfNeeded()

        #if DIRECT_DISTRIBUTION
            let isTrusted = { AutoPasteService.isTrusted }
            let openAccessibility = { AutoPasteService.openSettingsPane() }
            let revealApp = { AutoPasteService.revealAppInFinder() }
        #else
            let isTrusted = { false }
            let openAccessibility = {}
            let revealApp = {}
        #endif

        settings = SettingsController(
            prefs: prefs,
            store: store,
            update: currentUpdateModel,
            supportsAutoPaste: supportsAutoPaste,
            isAccessibilityTrusted: isTrusted,
            onOpenAccessibilitySettings: openAccessibility,
            onRevealAppInFinder: revealApp,
            onHotKeyChanged: { [weak self] in
                self?.installHotKey()
                self?.refreshStatusItem()
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
            onHighlightChanged: { [weak self] _ in self?.model?.reload(refreshChrome: false) },
            onThemeChanged: { [weak self] _ in self?.model?.reload(refreshChrome: false) },
            onRetentionChanged: { [weak self] in self?.model?.reload(refreshChrome: true) },
            onClearLastHour: { [weak self] in self?.clearRecent(seconds: 3600) },
            onClearAllHistory: { [weak self] in self?.clearHistory() },
            isCapturePaused: { [weak self] in self?.isPaused ?? false },
            onToggleCapturePaused: { [weak self] paused in self?.setCapturePaused(paused) }
        )

        #if DIRECT_DISTRIBUTION
            updateService.startIfEnabled()
        #endif
    }

    private func deliverPaste(payload: [(uti: String, data: Data)], prefs: Preferences, hint: PasteHintController) async
    {
        PasteService.write(payload)
        ReviewPrompt.recordCopyAndPromptIfEligible(prefs: prefs)
        #if DIRECT_DISTRIBUTION
            let pasted = await AutoPasteService.pasteAfterHide(auto: prefs.autoPaste)
            if !pasted { hint.showIfNeeded() }
        #else
            hint.showIfNeeded()
        #endif
    }

    private func startRetentionSweepLoop(store: Store) {
        sweepTask?.cancel()
        sweepTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3600))
                guard !Task.isCancelled else { return }
                _ = try? await store.sweepExpired()
            }
        }
    }

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

    private func refreshStatusItem() {
        statusItem?.button?.appearsDisabled = isPaused
        statusItem?.button?.toolTip = isPaused ? String(localized: "Pano — paused") : "Pano"
        statusItem?.menu = buildMenu()
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        let open = menu.addItem(
            withTitle: String(localized: "Open Pano"), action: #selector(openPanel), keyEquivalent: ""
        )
        open.target = self
        if let prefs {
            let eq = Self.menuKeyEquivalent(for: prefs.hotKeyCode)
            open.keyEquivalent = eq
            open.keyEquivalentModifierMask = Self.cocoaModifiers(from: prefs.hotKeyModifiers)
        }

        let pause = menu.addItem(
            withTitle: String(localized: "Pause capture"), action: #selector(togglePause), keyEquivalent: ""
        )
        pause.target = self
        pause.state = isPaused ? .on : .off

        menu.addItem(.separator())
        let clearMenu = NSMenu()
        clearMenu.addItem(
            withTitle: String(localized: "Last 15 Minutes"), action: #selector(clearLast15Minutes), keyEquivalent: ""
        ).target = self
        clearMenu.addItem(
            withTitle: String(localized: "Last Hour"), action: #selector(clearLastHour), keyEquivalent: ""
        ).target = self
        clearMenu.addItem(.separator())
        clearMenu.addItem(
            withTitle: String(localized: "All Unpinned…"), action: #selector(clearHistory), keyEquivalent: ""
        ).target = self
        let clearRoot = NSMenuItem(title: String(localized: "Clear History"), action: nil, keyEquivalent: "")
        clearRoot.submenu = clearMenu
        menu.addItem(clearRoot)

        #if DIRECT_DISTRIBUTION
            let updateTitle: String
            if let release = updateService?.model.availableRelease {
                updateTitle = String(localized: "Update Available (v\(release.version))…")
            } else {
                updateTitle = String(localized: "Check for Updates…")
            }
            menu.addItem(withTitle: updateTitle, action: #selector(checkForUpdates), keyEquivalent: "")
                .target = self
        #endif

        menu.addItem(withTitle: String(localized: "Settings…"), action: #selector(openSettings), keyEquivalent: ",")
            .target = self

        menu.addItem(.separator())
        menu.addItem(
            withTitle: String(localized: "Quit Pano"), action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        return menu
    }

    private static func cocoaModifiers(from carbon: UInt32) -> NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if carbon & UInt32(cmdKey) != 0 { flags.insert(.command) }
        if carbon & UInt32(shiftKey) != 0 { flags.insert(.shift) }
        if carbon & UInt32(optionKey) != 0 { flags.insert(.option) }
        if carbon & UInt32(controlKey) != 0 { flags.insert(.control) }
        return flags
    }

    private static func menuKeyEquivalent(for keyCode: UInt32) -> String {
        switch Int(keyCode) {
        case kVK_ANSI_A: return "a"
        case kVK_ANSI_B: return "b"
        case kVK_ANSI_C: return "c"
        case kVK_ANSI_D: return "d"
        case kVK_ANSI_E: return "e"
        case kVK_ANSI_F: return "f"
        case kVK_ANSI_G: return "g"
        case kVK_ANSI_H: return "h"
        case kVK_ANSI_I: return "i"
        case kVK_ANSI_J: return "j"
        case kVK_ANSI_K: return "k"
        case kVK_ANSI_L: return "l"
        case kVK_ANSI_M: return "m"
        case kVK_ANSI_N: return "n"
        case kVK_ANSI_O: return "o"
        case kVK_ANSI_P: return "p"
        case kVK_ANSI_Q: return "q"
        case kVK_ANSI_R: return "r"
        case kVK_ANSI_S: return "s"
        case kVK_ANSI_T: return "t"
        case kVK_ANSI_U: return "u"
        case kVK_ANSI_V: return "v"
        case kVK_ANSI_W: return "w"
        case kVK_ANSI_X: return "x"
        case kVK_ANSI_Y: return "y"
        case kVK_ANSI_Z: return "z"
        case kVK_Space: return " "
        default: return ""
        }
    }

    @objc private func openPanel() {
        guard let panel, !panel.isVisible else { return }
        toggle()
    }

    @objc private func openSettings() {
        settings?.show()
    }

    private func openUpdates() {
        settings?.show(tab: .about)
    }

    #if DIRECT_DISTRIBUTION
        @objc private func checkForUpdates() {
            settings?.show(tab: .about)
            if updateService?.model.availableRelease == nil, updateService?.model.isBusy == false {
                updateService?.check(userInitiated: true)
            }
        }
    #endif

    @objc private func togglePause() {
        setCapturePaused(!isPaused)
    }

    private func setCapturePaused(_ paused: Bool) {
        isPaused = paused
        Task { await engine?.setPaused(paused) }
        refreshStatusItem()
    }

    @objc private func clearLast15Minutes() {
        clearRecent(seconds: 900)
    }

    @objc private func clearLastHour() {
        clearRecent(seconds: 3600)
    }

    private func clearRecent(seconds: TimeInterval) {
        let cutoff = Date().addingTimeInterval(-seconds)
        Task { @MainActor in
            _ = try? await store?.clearHistory(since: cutoff)
            PreviewCache.shared.clearAll()
            model?.reload(refreshChrome: true)
        }
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
            PreviewCache.shared.clearAll()
            model?.reload(refreshChrome: true)
        }
    }

    private func toggle() {
        guard let panel else { return }
        if panel.isVisible {
            panel.hide()
            return
        }
        model?.activate()
        panel.show()
        Task { @MainActor in
            if await engine?.tick() != nil { model?.reload(refreshChrome: true) }
        }
    }

    private static func storeFolder() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        #if DEBUG
            let name = ProcessInfo.processInfo.environment["PANO_STORE_FOLDER"] ?? "Pano"
        #else
            let name = "Pano"
        #endif
        return base.appendingPathComponent(name, isDirectory: true)
    }
}
