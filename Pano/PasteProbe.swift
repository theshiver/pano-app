import AppKit

/// Throwaway week 0 probe, replaced by PanoCore.PasteService in week 1.
/// Same mechanism as docs/adr/0003: write to the pasteboard, post ⌘V with CGEvent, needs Accessibility.
///
/// macOS 26/27 finding: kTCCServiceAccessibility "does not allow prompting", so
/// AXIsProcessTrustedWithOptions raises no dialog. The disclosure prompt fires when the app
/// actually posts an event, so we always attempt the post; the first attempt on an untrusted
/// app triggers the system "Pano would like to control this Mac" prompt and adds Pano to the list.
@MainActor
enum PasteProbe {
    static func pasteHello() -> String {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString("hello from Pano", forType: .string)

        let source = CGEventSource(stateID: .combinedSessionState)
        let keyV: CGKeyCode = 9  // kVK_ANSI_V; layout-aware lookup is PasteService's job
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: keyV, keyDown: true),
            let up = CGEvent(keyboardEventSource: source, virtualKey: keyV, keyDown: false)
        else { return "CGEvent creation failed" }
        down.flags = .maskCommand
        up.flags = .maskCommand
        down.post(tap: .cgSessionEventTap)
        up.post(tap: .cgSessionEventTap)

        if AXIsProcessTrusted() {
            return "⌘V posted"
        }
        return "Posted, but Accessibility is not granted yet. If macOS asked, allow it, then try again."
    }
}
