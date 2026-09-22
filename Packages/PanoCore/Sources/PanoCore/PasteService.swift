import AppKit
import Foundation
import PanoStore

/// Writes a stored clip back to the pasteboard and pastes it into the previously focused app
/// (docs/adr/0003). No pasteboard restore: the chosen item becomes the clipboard.
///
/// The caller hides the panel first so the previous app regains key focus, then calls `paste`.
@MainActor
public enum PasteService {
    /// Writes the representations to the pasteboard, and — only when `auto` is true — posts ⌘V after
    /// a short delay that lets focus settle on the previous app.
    ///
    /// `auto` is the user's "Paste automatically" preference, which is off until they turn it on.
    /// While it is off this posts no events at all, so macOS never raises the "would like to control
    /// this Mac" prompt and the clip simply becomes the clipboard for the user to paste themselves.
    ///
    /// When it is on, the post is unconditional — it is *not* guarded on `AXIsProcessTrusted()`,
    /// because on macOS 26/27 that prompt only appears when the app actually posts an event, so
    /// guarding on trust would mean the user is never asked and can never grant (docs/adr/0003).
    ///
    /// Returns whether the keystroke is expected to have landed in the other app. **False means the
    /// clip is only on the clipboard and the caller owes the user a visible explanation** — an ⏎
    /// that silently does nothing reads as a broken app.
    @discardableResult
    public static func paste(
        _ payload: [(uti: String, data: Data)],
        auto: Bool,
        settleDelay: Duration = .milliseconds(50)
    ) async -> Bool {
        write(payload)
        guard auto else { return false }
        try? await Task.sleep(for: settleDelay)
        postCommandV()
        return AXIsProcessTrusted()
    }

    /// Writes every representation as explicit `NSPasteboardItem`s: the non-file types on one item,
    /// each file URL as its own item so multiple files paste correctly (docs/03-data-model.md).
    /// Explicit items avoid mixing `setData` on the general pasteboard with `writeObjects`, which
    /// dropped the file URL and broke file paste-back.
    static func write(_ payload: [(uti: String, data: Data)]) {
        let pb = NSPasteboard.general
        pb.clearContents()

        var items: [NSPasteboardItem] = []
        let nonFile = payload.filter { $0.uti != "public.file-url" }
        if !nonFile.isEmpty {
            let item = NSPasteboardItem()
            for (uti, data) in nonFile {
                item.setData(data, forType: NSPasteboard.PasteboardType(uti))
            }
            items.append(item)
        }
        for entry in payload where entry.uti == "public.file-url" {
            let item = NSPasteboardItem()
            item.setData(entry.data, forType: NSPasteboard.PasteboardType("public.file-url"))
            items.append(item)
        }
        if !items.isEmpty { pb.writeObjects(items) }
    }

    /// Posts a harmless synthetic event (a mouse-move to the current location) so macOS raises the
    /// "would like to control this Mac" prompt and lists Pano in Device Control and Data Access. On
    /// macOS 26/27 that prompt only appears when the app actually posts an event, so this is how the
    /// permission is requested rather than an AX permission API (which does not prompt —
    /// docs/adr/0003).
    ///
    /// **Only ever called from the user turning "Paste automatically" on.** Nothing else in the app
    /// may call it: an app that raises this prompt before the user asks for the feature is exactly
    /// what the 1.0 (3) review rejected.
    public static func triggerAccessibilityPrompt() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let location = CGEvent(source: nil)?.location ?? .zero
        guard
            let move = CGEvent(
                mouseEventSource: source, mouseType: .mouseMoved,
                mouseCursorPosition: location, mouseButton: .left
            )
        else { return }
        move.post(tap: .cgSessionEventTap)
    }

    public static var isAccessibilityTrusted: Bool { AXIsProcessTrusted() }

    /// Opens the System Settings pane holding the switch. macOS 26/27 labels it "Device Control and
    /// Data Access"; the URL is still the old Accessibility one (verified on macOS 27.0).
    public static func openSettingsPane() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
        if let url { NSWorkspace.shared.open(url) }
    }

    static func postCommandV() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let keyV: CGKeyCode = 9  // kVK_ANSI_V; layout-aware lookup is a later refinement
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: keyV, keyDown: true),
            let up = CGEvent(keyboardEventSource: source, virtualKey: keyV, keyDown: false)
        else { return }
        down.flags = .maskCommand
        up.flags = .maskCommand
        down.post(tap: .cgSessionEventTap)
        up.post(tap: .cgSessionEventTap)
    }
}
