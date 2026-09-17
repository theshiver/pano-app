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

    /// Non-file representations go on the first item; each file URL becomes its own item so that
    /// multiple copied files paste correctly (docs/03-data-model.md).
    static func write(_ payload: [(uti: String, data: Data)]) {
        let pb = NSPasteboard.general
        pb.clearContents()
        for (uti, data) in payload where uti != "public.file-url" {
            pb.setData(data, forType: NSPasteboard.PasteboardType(uti))
        }
        let fileItems = payload.filter { $0.uti == "public.file-url" }.map { entry -> NSPasteboardItem in
            let item = NSPasteboardItem()
            item.setData(entry.data, forType: NSPasteboard.PasteboardType("public.file-url"))
            return item
        }
        if !fileItems.isEmpty { pb.writeObjects(fileItems) }
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
