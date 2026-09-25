import AppKit
import Foundation
import PanoStore

/// Writes a stored clip back to the pasteboard and pastes it into the previously focused app
/// (docs/adr/0003). No pasteboard restore: the chosen item becomes the clipboard.
///
/// The caller hides the panel first so the previous app regains key focus, then calls `paste`.
@MainActor
public enum PasteService {
    /// Writes the representations to the pasteboard, then posts ⌘V after a short delay that lets
    /// focus settle on the previous app — but only when the user turned "Paste automatically" on
    /// **and** has already granted the permission.
    ///
    /// Never posting while untrusted is the rule this whole file hangs on (docs/adr/0003, second
    /// addendum). On macOS 26/27, posting an event without the grant is what makes macOS raise its
    /// own "would like to control this Mac" dialog and add the app to the list. Pano never does
    /// that: the user adds Pano in System Settings themselves, as with every clipboard manager we
    /// checked on the Mac App Store.
    ///
    /// Returns whether the keystroke went out. **False means the clip is only on the clipboard and
    /// the caller owes the user a visible explanation** — an ⏎ that silently does nothing reads as
    /// a broken app.
    @discardableResult
    public static func paste(
        _ payload: [(uti: String, data: Data)],
        auto: Bool,
        settleDelay: Duration = .milliseconds(50)
    ) async -> Bool {
        write(payload)
        guard auto, AXIsProcessTrusted() else { return false }
        try? await Task.sleep(for: settleDelay)
        postCommandV()
        return true
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

    public static var isAccessibilityTrusted: Bool { AXIsProcessTrusted() }

    /// Opens the System Settings pane holding the switch. macOS 26/27 labels it "Device Control and
    /// Data Access"; the URL is still the old Accessibility one (verified on macOS 27.0).
    public static func openSettingsPane() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
        if let url { NSWorkspace.shared.open(url) }
    }

    /// Selects Pano.app in a Finder window. macOS does not add Pano to the permission list on its
    /// own (see `paste`), so the user has to add it with + or by dragging it in; this puts the app
    /// where they can see it.
    public static func revealAppInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])
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
