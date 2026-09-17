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

    func applicationDidFinishLaunching(_ notification: Notification) {
        let store: Store
        do {
            store = try Store(folder: Self.storeFolder())
        } catch {
            NSLog("Pano: failed to open store: \(error)")
            return
        }
        self.store = store

        let engine = CaptureEngine(store: store)
        self.engine = engine
        Task { await engine.start() }

        let panel = PanelController()
        self.panel = panel

        let actions = PanelActions(
            paste: { [weak panel] id in
                // Order matters (docs/adr/0003): hide the panel first so the previous app regains
                // key focus, let it settle, then write the payload and post ⌘V. Doing these in one
                // Task guarantees the sequence; two separate Tasks raced and ⌘V hit Pano itself.
                Task { @MainActor in
                    panel?.hide()
                    try? await Task.sleep(for: .milliseconds(60))
                    let payload = (try? await store.payload(of: id)) ?? []
                    await PasteService.paste(payload)
                }
            },
            close: { [weak panel] in
                Task { @MainActor in panel?.hide() }
            }
        )
        let model = PanelModel(store: store, actions: actions)
        self.model = model
        panel.setContent(PanelView(model: model), model: model)

        hotKey = GlobalHotKey { [weak self] in
            Task { @MainActor in self?.toggle() }
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
