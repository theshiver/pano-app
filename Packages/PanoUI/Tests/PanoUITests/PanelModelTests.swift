import AppKit
import Foundation
import Testing

@testable import PanoStore
@testable import PanoUI

@MainActor
private func makeModel() throws -> (PanelModel, Store, URL) {
    let folder = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("pano-ui-\(UUID().uuidString)", isDirectory: true)
    let store = try Store(folder: folder)
    let actions = PanelActions(paste: { _, _ in }, pasteText: { _, _ in }, close: {})
    return (PanelModel(store: store, actions: actions), store, folder)
}

private func text(_ s: String) -> ClipCapture {
    ClipCapture(kind: .text, content: s, representations: [.init(uti: "public.utf8-plain-text", data: Data(s.utf8))])
}

@MainActor
@Test func activateSelectsNewestFirst() async throws {
    let (model, store, folder) = try makeModel()
    defer { try? FileManager.default.removeItem(at: folder) }

    let now = Date()
    try await store.insert(text("oldest"), now: now)
    try await store.insert(text("newest"), now: now.addingTimeInterval(10))

    model.activate()
    try await Task.sleep(for: .milliseconds(50))
    #expect(model.items.first?.content == "newest")
    #expect(model.selectedId == model.items.first?.id)
}

@MainActor
@Test func arrowSelectionMovesByID() async throws {
    let (model, store, folder) = try makeModel()
    defer { try? FileManager.default.removeItem(at: folder) }

    let now = Date()
    try await store.insert(text("a"), now: now)
    try await store.insert(text("b"), now: now.addingTimeInterval(10))
    try await store.insert(text("c"), now: now.addingTimeInterval(20))

    model.activate()
    try await Task.sleep(for: .milliseconds(50))
    #expect(model.items.map(\.content) == ["c", "b", "a"])
    #expect(model.selectedId == model.items[0].id)

    model.moveSelection(by: 1)
    #expect(model.selectedId == model.items[1].id)
    model.moveSelection(by: 1)
    #expect(model.selectedId == model.items[2].id)
    model.moveSelection(by: 5)  // clamps
    #expect(model.selectedId == model.items[2].id)
    model.moveSelection(by: -10)  // clamps to top
    #expect(model.selectedId == model.items[0].id)
}

@MainActor
@Test func searchFiltersAndKeepsSelectionValid() async throws {
    let (model, store, folder) = try makeModel()
    defer { try? FileManager.default.removeItem(at: folder) }

    try await store.insert(text("apple pie"))
    try await store.insert(text("banana bread"))

    model.activate()
    try await Task.sleep(for: .milliseconds(50))
    model.query = "banana"
    try await Task.sleep(for: .milliseconds(50))
    #expect(model.items.count == 1)
    #expect(model.items.first?.content == "banana bread")
    #expect(model.selectedId == model.items.first?.id)
}

@MainActor
@Test func deleteMovesSelectionToNext() async throws {
    let (model, store, folder) = try makeModel()
    defer { try? FileManager.default.removeItem(at: folder) }

    let now = Date()
    try await store.insert(text("a"), now: now)
    try await store.insert(text("b"), now: now.addingTimeInterval(10))
    try await store.insert(text("c"), now: now.addingTimeInterval(20))
    model.activate()
    try await Task.sleep(for: .milliseconds(50))
    // items: c, b, a — selection on c
    model.deleteSelected()
    try await Task.sleep(for: .milliseconds(50))
    #expect(model.items.map(\.content) == ["b", "a"])
    #expect(model.selectedId == model.items.first?.id)  // moved to b
}

@MainActor
@Test func pinReordersToTop() async throws {
    let (model, store, folder) = try makeModel()
    defer { try? FileManager.default.removeItem(at: folder) }

    let now = Date()
    let aId = try await store.insert(text("a"), now: now)
    try await store.insert(text("b"), now: now.addingTimeInterval(10))
    model.activate()
    try await Task.sleep(for: .milliseconds(50))
    // items: b, a — select a, pin it
    model.select(aId)
    model.togglePinSelected()
    try await Task.sleep(for: .milliseconds(50))
    #expect(model.items.first?.content == "a")
    #expect(model.items.first?.isPinned == true)
}

@MainActor
@Test func wholeQueryTransformNameSelectsTransform() async throws {
    let (model, store, folder) = try makeModel()
    defer { try? FileManager.default.removeItem(at: folder) }

    try await store.insert(
        ClipCapture(
            kind: .text, content: "#2A6DF0",
            representations: [.init(uti: "public.utf8-plain-text", data: Data("#2A6DF0".utf8))]
        )
    )
    model.activate()
    try await Task.sleep(for: .milliseconds(50))
    model.query = "colour"
    try await Task.sleep(for: .milliseconds(50))
    // Not filtered away, and the colour transform is auto-selected.
    #expect(model.items.count == 1)
    #expect(model.activeTransformId == "colour")
}

@Test func searchCompletionSuggestsKeysAndValues() {
    let apps = ["Xcode", "Google Chrome"]
    #expect(PanelModel.completion(for: "t", apps: apps) == "ype:")
    #expect(PanelModel.completion(for: "invoice a", apps: apps) == "pp:")
    #expect(PanelModel.completion(for: "type:i", apps: apps) == "mage")
    #expect(PanelModel.completion(for: "app:x", apps: apps) == "code")
    #expect(PanelModel.completion(for: "app:g", apps: apps) == "oogle")
    #expect(PanelModel.completion(for: "type:image", apps: apps) == nil)
    #expect(PanelModel.completion(for: "hello ", apps: apps) == nil)
    #expect(PanelModel.completion(for: "", apps: apps) == nil)
}

@MainActor
@Test func richPreviewStripsHtmlBackgroundAndNormalizesExtremeFontSizes() {
    let html = "<p style='background-color:#ff0;color:#000;font-size:48px'>Big</p><p style='font-size:8px'>Tiny</p>"
    let attr = RichPreview.attributed(html: html)
    #expect(attr != nil)
    if let attr {
        let ns = NSAttributedString(attr)
        let full = NSRange(location: 0, length: ns.length)
        var foundBackground = false
        var minSize = CGFloat.greatestFiniteMagnitude
        var maxSize: CGFloat = 0
        ns.enumerateAttributes(in: full) { attrs, _, _ in
            if attrs[.backgroundColor] != nil { foundBackground = true }
            if let font = attrs[.font] as? NSFont {
                minSize = min(minSize, font.pointSize)
                maxSize = max(maxSize, font.pointSize)
            }
        }
        #expect(!foundBackground)
        #expect(minSize >= 12.0)
        #expect(maxSize <= 17.6)
    }
}

@MainActor
@Test func hotKeyRecorderFormatsSpecialKeysCleanly() {
    #expect(
        HotKeyRecorderField.RecorderView.displayString(
            keyCode: 49, modifiers: [.command, .shift], charactersIgnoringModifiers: " "
        ) == "⇧⌘Space"
    )
    #expect(
        HotKeyRecorderField.RecorderView.displayString(
            keyCode: 36, modifiers: [.command], charactersIgnoringModifiers: "\r"
        ) == "⌘↩"
    )
}
