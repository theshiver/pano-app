import AppKit

/// Throwaway week 0 probe, replaced by PanoCore.PasteService in week 1.
/// Same mechanism as docs/adr/0003: write to the pasteboard, post ⌘V with CGEvent, needs Accessibility.
@MainActor
enum PasteProbe {
    static func pasteHello() -> String {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString("hello from Pano", forType: .string)

        guard AXIsProcessTrusted() else {
            return "Accessibility not granted: item is on the clipboard, press ⌘V yourself"
        }
        let source = CGEventSource(stateID: .combinedSessionState)
        let keyV: CGKeyCode = 9  // kVK_ANSI_V; layout-aware lookup is PasteService's job
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: keyV, keyDown: true),
            let up = CGEvent(keyboardEventSource: source, virtualKey: keyV, keyDown: false)
        else { return "CGEvent creation failed" }
        down.flags = .maskCommand
        up.flags = .maskCommand
        down.post(tap: .cgSessionEventTap)
        up.post(tap: .cgSessionEventTap)
        return "⌘V posted"
    }
}
