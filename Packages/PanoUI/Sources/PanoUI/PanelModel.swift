import AppKit
import Foundation
import PanoCore
import PanoStore
import PanoTransforms

@MainActor
@Observable
public final class PanelModel {
    public private(set) var items: [ClipListItem] = []
    public private(set) var apps: [SourceApp] = []
    public private(set) var selectedAppId: String? {
        didSet { if selectedAppId != oldValue { reload(refreshChrome: false) } }
    }
    public private(set) var pinboards: [Pinboard] = []
    public private(set) var totalCount = 0
    public private(set) var storageBytes: Int64 = 0
    public private(set) var selectedPinboardId: Int64? {
        didSet { if selectedPinboardId != oldValue { reload(refreshChrome: false) } }
    }
    public var query: String = "" {
        didSet {
            if query != oldValue { reloadSearch() }
        }
    }
    public private(set) var selectedId: Int64? {
        didSet {
            if selectedId != oldValue {
                recomputeAvailableTransforms()
                activeTransformId = renderMarkdown && selectedIsMarkdown ? "markdown" : nil
                recomputeTransformOutput()
            }
        }
    }
    public var activeTransformId: String? {
        didSet {
            if activeTransformId != oldValue {
                recomputeTransformOutput()
                if activeTransformId != nil { prefs?.usedPowerFeature = true }
            }
        }
    }
    public private(set) var availableTransforms: [any Transform] = []
    public private(set) var transformOutput: TransformOutput?

    public var prefs: Preferences?
    public var update: UpdateModel?
    public var highlightCode: Bool {
        get { prefs?.highlightCode ?? true }
        set { prefs?.highlightCode = newValue }
    }
    public var syntaxTheme: String { prefs?.syntaxTheme ?? "atom-one-dark" }
    public var ocrEnabled: Bool {
        get { prefs?.ocrEnabled ?? true }
        set { prefs?.ocrEnabled = newValue }
    }
    public var onOCRChanged: ((Bool) -> Void)?
    public var renderMarkdown: Bool {
        get { prefs?.renderMarkdown ?? true }
        set { prefs?.renderMarkdown = newValue }
    }
    public var commandHeld: Bool = false
    public var supportsAutoPaste = false
    public var isAccessibilityTrusted: (@MainActor () -> Bool)?
    public var searchDebounce: Duration = .zero

    public var autoPasteActive: Bool {
        supportsAutoPaste && (prefs?.autoPaste == true) && (isAccessibilityTrusted?() ?? false)
    }

    public private(set) var focusRequests = 0
    public func requestSearchFocus() { focusRequests += 1 }

    private let store: Store
    private let actions: PanelActions
    private var reloadTask: Task<Void, Never>?

    public init(store: Store, actions: PanelActions) {
        self.store = store
        self.actions = actions
        ClipDrag.payload = { id in (try? await store.payload(of: id)) ?? [] }
    }

    public func activate() {
        query = ""
        selectedAppId = nil
        selectedPinboardId = nil
        reload(selectTop: true, refreshChrome: true)
    }

    public func reload(selectTop: Bool = false, refreshChrome: Bool = true) {
        runReload(selectTop: selectTop, refreshChrome: refreshChrome, debounce: .zero)
    }

    private func reloadSearch() {
        runReload(selectTop: false, refreshChrome: false, debounce: searchDebounce)
    }

    private func runReload(selectTop: Bool, refreshChrome: Bool, debounce: Duration) {
        let (searchText, transformToken) = Self.splitTransformToken(query)
        reloadTask?.cancel()
        let appId = selectedAppId
        let boardId = selectedPinboardId
        reloadTask = Task {
            if debounce > .zero {
                try? await Task.sleep(for: debounce)
                guard !Task.isCancelled else { return }
            }
            if refreshChrome {
                async let rail = (try? await store.sourceApps(limit: 12)) ?? []
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
            } else {
                let result = await fetch(appId.map { "app:\($0) " + searchText } ?? searchText, pinboardId: boardId)
                guard !Task.isCancelled else { return }
                items = result
            }
            if let appId, !apps.contains(where: { $0.id == appId }) { selectedAppId = nil }
            if selectTop || selectedId == nil || !items.contains(where: { $0.id == selectedId }) {
                selectedId = items.first?.id
            } else {
                recomputeAvailableTransforms()
                recomputeTransformOutput()
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

    static func splitTransformToken(_ query: String) -> (String, String?) {
        let trimmed = query.trimmingCharacters(in: .whitespaces).lowercased()
        if transformIds.contains(trimmed) { return ("", trimmed) }
        return (query, nil)
    }

    // MARK: Search completion

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

    public func setQuickFilter(_ token: String) {
        query = token
        requestSearchFocus()
    }

    // MARK: Rail

    public func selectApp(_ bundleId: String?) {
        selectedAppId = (selectedAppId == bundleId) ? nil : bundleId
    }

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
            reload(refreshChrome: true)
        }
    }

    public func deletePinboard(_ id: Int64) {
        if selectedPinboardId == id { selectedPinboardId = nil }
        Task {
            try? await store.deletePinboard(id: id)
            reload(refreshChrome: true)
        }
    }

    public func addClip(_ clipId: Int64, toPinboard id: Int64) {
        Task {
            try? await store.addToPinboard(clipId: clipId, pinboardId: id)
            reload(refreshChrome: true)
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
            reload(refreshChrome: true)
        }
    }

    // MARK: Transforms & selection

    public var selectedItem: ClipListItem? {
        items.first { $0.id == selectedId }
    }

    private func recomputeAvailableTransforms() {
        guard let item = selectedItem, item.kind != .image, item.kind != .file,
            let content = item.content, !content.isEmpty
        else {
            availableTransforms = []
            return
        }
        availableTransforms = Transforms.applicable(to: content)
    }

    private func recomputeTransformOutput() {
        guard let transform = activeTransform, let content = selectedItem?.content else {
            transformOutput = nil
            return
        }
        transformOutput = try? transform.apply(content)
    }

    public func imageData(for id: Int64) async -> Data? {
        let payload = (try? await store.payload(of: id)) ?? []
        let data = payload.first { PasteboardUTIs.imageUTIs.contains($0.uti) }?.data
        if data != nil { fileClipsWithImage.insert(id) }
        return data
    }

    public func thumbnail(for id: Int64) async -> NSImage? {
        if let cached = PreviewCache.shared.thumbnail(for: id) { return cached }
        guard let data = await imageData(for: id) else { return nil }
        let cgImage = await Task.detached(priority: .utility) {
            PreviewCache.decodeDownsampledCGImage(from: data, maxPixelSize: 64)
        }.value
        let image = PreviewCache.makeImage(from: cgImage, fallbackData: data)
        if let image { PreviewCache.shared.setThumbnail(image, for: id) }
        return image
    }

    public private(set) var fileClipsWithImage: Set<Int64> = []

    public func hasImage(_ item: ClipListItem) -> Bool {
        item.kind == .image || fileClipsWithImage.contains(item.id)
    }

    public func payload(for id: Int64) async -> [(uti: String, data: Data)] {
        (try? await store.payload(of: id)) ?? []
    }

    public var activeTransform: (any Transform)? {
        availableTransforms.first { $0.id == activeTransformId }
    }

    public func toggleTransform(_ id: String) {
        activeTransformId = (activeTransformId == id) ? nil : id
    }

    public func toggleHighlight() {
        highlightCode.toggle()
    }

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
            prefs?.usedPowerFeature = true
            reload(refreshChrome: false)
        }
    }

    public var selectedIsMarkdown: Bool {
        guard let item = selectedItem, item.kind == .code, let content = item.content else { return false }
        return PreviewCache.shared.language(for: item) == .markdown
    }

    public func pasteText(_ text: String) {
        actions.pasteText(text, nil)
    }

    public func neighborItems(around id: Int64) -> [ClipListItem] {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return [] }
        var neighbors: [ClipListItem] = []
        if items.indices.contains(idx + 1) { neighbors.append(items[idx + 1]) }
        if items.indices.contains(idx - 1) { neighbors.append(items[idx - 1]) }
        return neighbors
    }

    // MARK: Keyboard & Row Actions

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
            prefs?.usedPowerFeature = true
            actions.pasteText(output.text, output.html)
        } else if plainText, let ocr = item.ocrText, !ocr.isEmpty {
            prefs?.usedPowerFeature = true
            actions.pasteText(ocr, nil)
        } else {
            actions.paste(selectedId, plainText)
        }
    }

    public func copyItem(_ id: Int64, plainText: Bool = false) {
        select(id)
        actions.paste(id, plainText)
    }

    public func pasteRank(_ rank: Int) {
        guard items.indices.contains(rank - 1) else { return }
        actions.paste(items[rank - 1].id, false)
    }

    public func togglePinSelected() {
        guard let id = selectedId else { return }
        togglePin(id)
    }

    public func togglePin(_ id: Int64) {
        guard let item = items.first(where: { $0.id == id }) else { return }
        let newValue = !item.isPinned
        Task {
            try? await store.setPinned(newValue, id: id)
            reload(refreshChrome: true)
        }
    }

    public func deleteSelected() {
        guard let id = selectedId else { return }
        let index = items.firstIndex { $0.id == id } ?? 0
        let nextId =
            items.indices.contains(index + 1)
            ? items[index + 1].id
            : (index > 0 ? items[index - 1].id : nil)
        selectedId = nextId
        deleteItem(id)
    }

    public func deleteItem(_ id: Int64) {
        PreviewCache.shared.invalidate(id: id)
        let boardId = selectedPinboardId
        Task {
            if let boardId {
                try? await store.removeFromPinboard(clipId: id, pinboardId: boardId)
            } else {
                try? await store.delete(id: id)
            }
            reload(refreshChrome: true)
        }
    }

    public func close() {
        actions.close()
    }

    public func openSettings() {
        actions.close()
        actions.openSettings()
    }

    public func openUpdates() {
        actions.close()
        actions.openUpdates()
    }
}
