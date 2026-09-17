import Foundation
import PanoStore
import PanoTransforms

/// Drives the panel: loads recent clips, runs search as the query changes, tracks the selected
/// row **by clip id** (so selection survives an async reload), and forwards a paste to the app
/// target. `@MainActor` and `@Observable`; all store access is async off the actor.
@MainActor
@Observable
public final class PanelModel {
    public private(set) var items: [ClipListItem] = []
    public var query: String = "" {
        didSet { if query != oldValue { reload() } }
    }
    public private(set) var selectedId: Int64? {
        didSet { if selectedId != oldValue { activeTransformId = nil } }
    }
    /// The transform whose chip is active in the preview, if any.
    public var activeTransformId: String?
    /// True while ⌘ is held, so the list can show the ⌘1–9 quick-paste numbers.
    public var commandHeld: Bool = false

    private let store: Store
    private let actions: PanelActions
    private var reloadTask: Task<Void, Never>?

    public init(store: Store, actions: PanelActions) {
        self.store = store
        self.actions = actions
    }

    /// Called when the panel is shown: reset the query and load the newest clips, selecting the top.
    public func activate() {
        query = ""
        reload(selectTop: true)
    }

    public func reload(selectTop: Bool = false) {
        // A trailing token matching a transform name selects that transform instead of filtering
        // (docs/02-architecture.md), so strip it before searching.
        let (searchText, transformToken) = Self.splitTransformToken(query)
        reloadTask?.cancel()
        reloadTask = Task {
            let result = await fetch(searchText)
            guard !Task.isCancelled else { return }
            items = result
            if selectTop || selectedId == nil || !items.contains(where: { $0.id == selectedId }) {
                selectedId = items.first?.id
            }
            if let transformToken, availableTransforms.contains(where: { $0.id == transformToken }) {
                activeTransformId = transformToken
            }
        }
    }

    private func fetch(_ query: String) async -> [ClipListItem] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        return (try? trimmed.isEmpty ? await store.recent() : await store.search(trimmed)) ?? []
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

    // MARK: Transforms & selection

    public var selectedItem: ClipListItem? {
        items.first { $0.id == selectedId }
    }

    public var availableTransforms: [any Transform] {
        guard let content = selectedItem?.content, !content.isEmpty else { return [] }
        return Transforms.applicable(to: content)
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
    }

    /// Pastes an arbitrary string (a transformed value or a colour format row) as plain text.
    public func pasteText(_ text: String) {
        actions.pasteText(text)
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
        guard let selectedId else { return }
        if !plainText, let output = transformOutput {
            actions.pasteText(output.text)  // ⏎ with a transform active pastes the transformed value
        } else {
            actions.paste(selectedId, plainText)  // ⇧⏎ (or no transform) pastes the stored item
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

    public func deleteSelected() {
        guard let id = selectedId else { return }
        // Move selection to the next row (or the previous if this was the last) before it vanishes.
        let index = items.firstIndex { $0.id == id } ?? 0
        let nextId =
            items.indices.contains(index + 1)
            ? items[index + 1].id
            : (index > 0 ? items[index - 1].id : nil)
        selectedId = nextId
        Task {
            try? await store.delete(id: id)
            reload()
        }
    }

    public func close() {
        actions.close()
    }
}
