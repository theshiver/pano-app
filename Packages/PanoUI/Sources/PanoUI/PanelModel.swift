import Foundation
import PanoCore
import PanoStore
import PanoTransforms

/// Drives the panel: loads recent clips, runs search as the query changes, tracks the selected
/// row **by clip id** (so selection survives an async reload), and forwards a paste to the app
/// target. `@MainActor` and `@Observable`; all store access is async off the actor.
@MainActor
@Observable
public final class PanelModel {
    public private(set) var items: [ClipListItem] = []
    /// The rail: apps clips came from, and the one currently filtering the list (nil = all).
    public private(set) var apps: [SourceApp] = []
    public private(set) var selectedAppId: String? {
        didSet { if selectedAppId != oldValue { reload() } }
    }
    public private(set) var pinboards: [Pinboard] = []
    /// Whole-history figures for the status bar (the list itself is capped at 200 rows).
    public private(set) var totalCount = 0
    public private(set) var storageBytes: Int64 = 0
    public private(set) var selectedPinboardId: Int64? {
        didSet { if selectedPinboardId != oldValue { reload() } }
    }
    public var query: String = "" {
        didSet { if query != oldValue { reload() } }
    }
    public private(set) var selectedId: Int64? {
        didSet {
            if selectedId != oldValue { activeTransformId = renderMarkdown && selectedIsMarkdown ? "markdown" : nil }
        }
    }
    /// The transform whose chip is active in the preview, if any.
    public var activeTransformId: String?
    /// The app's preferences; the preview's Highlight and Markdown chips toggle them in place so
    /// nobody has to open Settings. nil in tests.
    public var prefs: Preferences?
    /// Whether to syntax-highlight code and show the detected language.
    public var highlightCode: Bool {
        get { prefs?.highlightCode ?? true }
        set { prefs?.highlightCode = newValue }
    }
    public var syntaxTheme: String { prefs?.syntaxTheme ?? "atom-one-dark" }
    /// OCR for images. The app hooks `onOCRChanged` so the capture engine follows the chip.
    public var ocrEnabled: Bool {
        get { prefs?.ocrEnabled ?? true }
        set { prefs?.ocrEnabled = newValue }
    }
    public var onOCRChanged: ((Bool) -> Void)?
    /// Whether a Markdown clip opens with the Markdown transform already active.
    public var renderMarkdown: Bool {
        get { prefs?.renderMarkdown ?? true }
        set { prefs?.renderMarkdown = newValue }
    }
    /// True while ⌘ is held, so the list can show the ⌘1–9 quick-paste numbers.
    public var commandHeld: Bool = false

    /// Whether the permission behind auto-paste is currently granted. Refreshed by the controller
    /// when the panel opens rather than read per render: the user can revoke it in System Settings
    /// while Pano is running, but not between two frames of the same panel.
    public private(set) var isAccessibilityTrusted = false

    /// Whether ⏎ will land the clip in the app the user came from, or only put it on the clipboard
    /// for them to paste. Off unless the user turned "Paste automatically" on *and* the permission
    /// it needs is still granted; the preview footer tells them which of the two they are getting.
    public var willAutoPaste: Bool { (prefs?.autoPaste ?? false) && isAccessibilityTrusted }

    public func setAccessibilityTrusted(_ trusted: Bool) {
        isAccessibilityTrusted = trusted
    }

    /// Bumped by the controller every time the panel is ordered front, so the view can put first
    /// responder back on the search field.
    ///
    /// The view cannot do this in `onAppear`: that fires once, when the hosting view is attached at
    /// launch, while the panel is still hidden and cannot take focus — so the focus is dropped and,
    /// because the view never disappears, never asked for again. The panel then opens dead to the
    /// keyboard until the user clicks into the field.
    public private(set) var focusRequests = 0

    public func requestSearchFocus() { focusRequests += 1 }

    private let store: Store
    private let actions: PanelActions
    private var reloadTask: Task<Void, Never>?

    public init(store: Store, actions: PanelActions) {
        self.store = store
        self.actions = actions
        ClipDrag.payload = { id in (try? await store.payload(of: id)) ?? [] }  // drag-out loads bytes lazily
    }

    /// Called when the panel is shown: reset the query and load the newest clips, selecting the top.
    public func activate() {
        query = ""
        selectedAppId = nil
        selectedPinboardId = nil
        reload(selectTop: true)
    }

    public func reload(selectTop: Bool = false) {
        // A trailing token matching a transform name selects that transform instead of filtering
        // (docs/02-architecture.md), so strip it before searching.
        let (searchText, transformToken) = Self.splitTransformToken(query)
        reloadTask?.cancel()
        let appId = selectedAppId
        let boardId = selectedPinboardId
        reloadTask = Task {
            async let rail = (try? await store.sourceApps(limit: 6)) ?? []  // leaves room for pinboards below
            async let boards = (try? await store.pinboards()) ?? []
            async let total = (try? await store.count()) ?? 0
            async let bytes = await store.storageBytes()
            let result = await fetch(appId.map { "app:\($0) " + searchText } ?? searchText, pinboardId: boardId)
            guard !Task.isCancelled else { return }
            items = result
            apps = await rail
            pinboards = await boards
            totalCount = await total
            storageBytes = await bytes
            if let appId, !apps.contains(where: { $0.id == appId }) { selectedAppId = nil }
            if selectTop || selectedId == nil || !items.contains(where: { $0.id == selectedId }) {
                selectedId = items.first?.id
            }
            if let transformToken, availableTransforms.contains(where: { $0.id == transformToken }) {
                activeTransformId = transformToken
            }
        }
    }

    private func fetch(_ query: String, pinboardId: Int64?) async -> [ClipListItem] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty, pinboardId == nil { return (try? await store.recent()) ?? [] }
        return (try? await store.search(trimmed, pinboardId: pinboardId)) ?? []
    }

    private static let transformIds = Set(Transforms.all.map(\.id))

    /// If the whole query is a transform name, it selects that transform for the current item
    /// instead of searching (docs/02-architecture.md). Matching only the exact whole query keeps it
    /// predictable; a looser "trailing token after other terms" rule would strip real searches like
    /// "invoice json". Returns the effective search text and the transform id, if any.
    static func splitTransformToken(_ query: String) -> (String, String?) {
        let trimmed = query.trimmingCharacters(in: .whitespaces).lowercased()
        if transformIds.contains(trimmed) { return ("", trimmed) }
        return (query, nil)
    }

    // MARK: Search completion

    /// Inline ghost text for the search field: the rest of a filter key (`t` → `ype:`) or of a
    /// filter value (`type:i` → `mage`, `app:x` → `code`). Tab or → accepts it. nil when nothing fits.
    public var completion: String? {
        Self.completion(for: query, apps: apps.compactMap(\.name))
    }

    nonisolated static let filterKeys = ["type:", "app:", "pinned:"]
    nonisolated static let kindValues = ["text", "code", "url", "image", "file", "colour", "richtext"]

    nonisolated static func completion(for query: String, apps: [String]) -> String? {
        guard let last = query.split(separator: " ", omittingEmptySubsequences: false).last, !last.isEmpty else {
            return nil
        }
        let token = last.lowercased()
        func suffix(_ candidates: [String], after prefix: String) -> String? {
            candidates.first { $0.lowercased().hasPrefix(prefix) && $0.lowercased() != prefix }
                .map { String($0.dropFirst(prefix.count)) }
        }
        guard let colon = token.firstIndex(of: ":") else { return suffix(filterKeys, after: token) }
        let value = String(token[token.index(after: colon)...])
        switch token[...colon] {
        case "type:": return suffix(kindValues, after: value)
        case "app:": return suffix(apps.map { $0.split(separator: " ").first.map(String.init) ?? $0 }, after: value)
        default: return nil
        }
    }

    public func acceptCompletion() -> Bool {
        guard let completion else { return false }
        query += completion + (completion.hasSuffix(":") ? "" : " ")
        return true
    }

    // MARK: Rail

    /// Tapping the active app's icon (or "All") clears the filter.
    public func selectApp(_ bundleId: String?) {
        selectedAppId = (selectedAppId == bundleId) ? nil : bundleId
    }

    /// ⌘] / ⌘[ walk the rail; before the first app is "All".
    public func moveAppSelection(by delta: Int) {
        guard !apps.isEmpty else { return }
        let current = apps.firstIndex { $0.id == selectedAppId } ?? -1
        let next = min(max(-1, current + delta), apps.count - 1)
        selectedAppId = next < 0 ? nil : apps[next].id
    }

    // MARK: Pinboards

    public func selectPinboard(_ id: Int64?) {
        selectedPinboardId = (selectedPinboardId == id) ? nil : id
    }

    public func createPinboard(name: String, colour: String, icon: String?) {
        Task {
            _ = try? await store.createPinboard(name: name, colour: colour, icon: icon)
            reload()
        }
    }

    public func deletePinboard(_ id: Int64) {
        if selectedPinboardId == id { selectedPinboardId = nil }
        Task {
            try? await store.deletePinboard(id: id)
            reload()
        }
    }

    /// Drop target and ⌘⇧1–9: adds the clip to the board (dropping it on a board it is already on
    /// is a no-op; ⌘⇧n toggles).
    public func addClip(_ clipId: Int64, toPinboard id: Int64) {
        Task {
            try? await store.addToPinboard(clipId: clipId, pinboardId: id)
            reload()
        }
    }

    public func toggleSelectedClipInPinboard(rank: Int) {
        guard let clipId = selectedId, pinboards.indices.contains(rank - 1) else { return }
        let boardId = pinboards[rank - 1].id
        Task {
            let member = (try? await store.pinboardIds(of: clipId))?.contains(boardId) ?? false
            if member {
                try? await store.removeFromPinboard(clipId: clipId, pinboardId: boardId)
            } else {
                try? await store.addToPinboard(clipId: clipId, pinboardId: boardId)
            }
            reload()
        }
    }

    // MARK: Transforms & selection

    public var selectedItem: ClipListItem? {
        items.first { $0.id == selectedId }
    }

    public var availableTransforms: [any Transform] {
        guard let item = selectedItem, item.kind != .image, item.kind != .file,
            let content = item.content, !content.isEmpty
        else { return [] }
        return Transforms.applicable(to: content)
    }

    /// Loads the image bytes of a clip for the preview (png or tiff). Async because the payload may
    /// live in a blob file, not the row.
    public func imageData(for id: Int64) async -> Data? {
        let imageUTIs: Set<String> = [
            "public.png", "public.tiff", "public.jpeg", "public.heic", "com.compuserve.gif",
        ]
        let payload = (try? await store.payload(of: id)) ?? []
        let data = payload.first { imageUTIs.contains($0.uti) }?.data
        if data != nil { fileClipsWithImage.insert(id) }
        return data
    }

    /// File clips that turned out to carry image bytes (an image copied in Finder), learned when
    /// the preview loads them; the OCR chip shows for these, not for every file.
    public private(set) var fileClipsWithImage: Set<Int64> = []

    public func hasImage(_ item: ClipListItem) -> Bool {
        item.kind == .image || fileClipsWithImage.contains(item.id)
    }

    /// The stored representations of a clip (for the rich-text preview and drag-out).
    public func payload(for id: Int64) async -> [(uti: String, data: Data)] {
        (try? await store.payload(of: id)) ?? []
    }

    public var activeTransform: (any Transform)? {
        availableTransforms.first { $0.id == activeTransformId }
    }

    public var transformOutput: TransformOutput? {
        guard let transform = activeTransform, let content = selectedItem?.content else { return nil }
        return try? transform.apply(content)
    }

    public func toggleTransform(_ id: String) {
        activeTransformId = (activeTransformId == id) ? nil : id
        // On a Markdown clip the chip doubles as the "render Markdown by default" preference.
        if id == "markdown", selectedIsMarkdown { renderMarkdown = activeTransformId == "markdown" }
    }

    public func toggleHighlight() {
        highlightCode.toggle()
    }

    /// The OCR chip: flips the preference, tells the engine, and — when turned on over an image
    /// that was captured while OCR was off — recognises that image right away.
    public func toggleOCR() {
        ocrEnabled.toggle()
        onOCRChanged?(ocrEnabled)
        guard ocrEnabled, let item = selectedItem, item.ocrText == nil else { return }
        let id = item.id
        Task {
            let payload = await payload(for: id)
            guard let image = payload.first(where: { PasteboardUTIs.imageUTIs.contains($0.uti) })?.data,
                let text = await OCRService.recognizeText(in: image)
            else { return }
            try? await store.setOCRText(text, id: id)
            reload()
        }
    }

    public var selectedIsMarkdown: Bool {
        guard let item = selectedItem, item.kind == .code, let content = item.content else { return false }
        return CodeHighlighter.detectLanguage(String(content.prefix(4000))) == .markdown
    }

    /// Pastes an arbitrary string (a transformed value or a colour format row) as plain text.
    public func pasteText(_ text: String) {
        actions.pasteText(text, nil)
    }

    // MARK: Keyboard

    public func moveSelection(by delta: Int) {
        guard !items.isEmpty else { return }
        let current = items.firstIndex { $0.id == selectedId } ?? 0
        let next = min(max(0, current + delta), items.count - 1)
        selectedId = items[next].id
    }

    public func select(_ id: Int64) {
        selectedId = id
    }

    public func pasteSelected(plainText: Bool = false) {
        guard let selectedId, let item = selectedItem else { return }
        if !plainText, let output = transformOutput {
            actions.pasteText(output.text, output.html)  // ⏎ with a transform active pastes the transformed value
        } else if plainText, let ocr = item.ocrText, !ocr.isEmpty {
            actions.pasteText(ocr, nil)  // ⇧⏎ on an OCR'd image pastes the recognised text
        } else {
            actions.paste(selectedId, plainText)  // ⏎ pastes the item; ⇧⏎ pastes it plain
        }
    }

    /// Numbered quick-paste: ⌘1…⌘9 paste the nth visible row (1-based).
    public func pasteRank(_ rank: Int) {
        guard items.indices.contains(rank - 1) else { return }
        actions.paste(items[rank - 1].id, false)
    }

    public func togglePinSelected() {
        guard let id = selectedId, let item = items.first(where: { $0.id == id }) else { return }
        let newValue = !item.isPinned
        Task {
            try? await store.setPinned(newValue, id: id)
            reload()  // keeps selectedId; re-sorts so pinned float to the top
        }
    }

    /// ⌘⌫: deletes the clip, or, while a pinboard is selected, removes it from that board.
    public func deleteSelected() {
        guard let id = selectedId else { return }
        // Move selection to the next row (or the previous if this was the last) before it vanishes.
        let index = items.firstIndex { $0.id == id } ?? 0
        let nextId =
            items.indices.contains(index + 1)
            ? items[index + 1].id
            : (index > 0 ? items[index - 1].id : nil)
        selectedId = nextId
        let boardId = selectedPinboardId
        Task {
            if let boardId {
                try? await store.removeFromPinboard(clipId: id, pinboardId: boardId)  // in a board, ⌘⌫ only unlinks
            } else {
                try? await store.delete(id: id)
            }
            reload()
        }
    }

    public func close() {
        actions.close()
    }

    public func openSettings() {
        actions.close()
        actions.openSettings()
    }
}
