import AppKit
import Foundation
import PanoStore
import Testing

@testable import PanoCore

/// These drive real ticks against the shared general pasteboard, so they must not run in
/// parallel with each other — hence a serialized suite. Each saves and restores the pasteboard
/// so a local run does not clobber the user's clipboard.
@Suite(.serialized)
struct CaptureEngineTests {
    @Test func tickRecordsANewCopy() async throws {
        let folder = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("pano-capture-\(UUID().uuidString)", isDirectory: true)
        let store = try Store(folder: folder)
        defer { try? FileManager.default.removeItem(at: folder) }

        let pb = NSPasteboard.general
        let saved = pb.pasteboardItems?.compactMap { item -> [(NSPasteboard.PasteboardType, Data)]? in
            item.types.compactMap { t in item.data(forType: t).map { (t, $0) } }
        }
        defer {
            pb.clearContents()
            if let saved {
                pb.writeObjects(
                    saved.map { entries in
                        let it = NSPasteboardItem()
                        for (t, d) in entries { it.setData(d, forType: t) }
                        return it
                    }
                )
            }
        }

        let engine = CaptureEngine(store: store)
        pb.clearContents()
        pb.setString("captured by the engine", forType: .string)

        let id = await engine.tick()
        #expect(id != nil)
        let rows = try await store.recent()
        #expect(rows.contains { $0.content == "captured by the engine" })
    }

    @Test func excludedAppIsSkipped() async throws {
        // CaptureBuilder is the pure path; here we check the engine's exclusion gate via its own bundle id.
        let folder = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("pano-excl-\(UUID().uuidString)", isDirectory: true)
        let store = try Store(folder: folder)
        defer { try? FileManager.default.removeItem(at: folder) }

        let frontmost = await MainActor.run { NSWorkspace.shared.frontmostApplication?.bundleIdentifier }
        guard let frontmost else { return }  // headless CI may have no frontmost app; skip
        let engine = CaptureEngine(store: store, excludedBundleIds: [frontmost])

        let pb = NSPasteboard.general
        let saved = pb.string(forType: .string)
        defer { if let saved { pb.clearContents(); pb.setString(saved, forType: .string) } }
        pb.clearContents()
        pb.setString("from an excluded app", forType: .string)

        #expect(await engine.tick() == nil)
        #expect(try await store.count() == 0)
    }
}
