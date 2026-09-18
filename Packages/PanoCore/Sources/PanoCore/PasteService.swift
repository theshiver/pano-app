import AppKit
import Foundation
import PanoStore

/// Writes a stored clip back to the pasteboard and pastes it into the previously focused app
/// (docs/adr/0003). No pasteboard restore: the chosen item becomes the clipboard.
///
/// The caller hides the panel first so the previous app regains key focus, then calls `paste`.
@MainActor
public enum PasteService {
    /// Writes the representations and posts ⌘V after a short delay that lets focus settle on the
    /// previous app. The post is **unconditional**: on macOS 26/27 the "would like to control this
    /// Mac" prompt only appears when the app actually posts an event, so guarding on
    /// `AXIsProcessTrusted()` would mean the user is never asked and can never grant (docs/adr/0003).
    /// Returns whether Accessibility is currently trusted, for the caller's own messaging.
    @discardableResult
    public static func paste(
        _ payload: [(uti: String, data: Data)],
        settleDelay: Duration = .milliseconds(50)
    ) async -> Bool {
        write(payload)
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
    /// "would like to control this Mac" prompt and adds Pano to the Accessibility list. On macOS
    /// 26/27 that prompt only appears when the app actually posts an event, so onboarding calls this
    /// rather than an AX permission API (which does not prompt — docs/adr/0003).
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
