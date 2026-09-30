import AppKit
import Foundation

/// Writes a stored clip back to the pasteboard, so the user pastes it with ⌘V. No pasteboard
/// restore: the chosen item becomes the clipboard.
///
/// Pano does not paste into other apps. Posting ⌘V needs a permission App Review would not accept
/// for this purpose, so the feature was removed (docs/adr/0008). Do not add event posting or any
/// Accessibility check back to this target.
@MainActor
public enum PasteService {
    /// Writes every representation as explicit `NSPasteboardItem`s: the non-file types on one item,
    /// each file URL as its own item so multiple files paste correctly (docs/03-data-model.md).
    /// Explicit items avoid mixing `setData` on the general pasteboard with `writeObjects`, which
    /// dropped the file URL and broke file paste-back.
    public static func write(_ payload: [(uti: String, data: Data)]) {
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
}
