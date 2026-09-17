import Foundation
import PanoStore

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
    public private(set) var selectedId: Int64?

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
        let query = query
        reloadTask?.cancel()
        reloadTask = Task {
            let result = await fetch(query)
            guard !Task.isCancelled else { return }
            items = result
            if selectTop || selectedId == nil || !items.contains(where: { $0.id == selectedId }) {
                selectedId = items.first?.id
            }
        }
    }

    private func fetch(_ query: String) async -> [ClipListItem] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        return (try? trimmed.isEmpty ? await store.recent() : await store.search(trimmed)) ?? []
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

    public func pasteSelected() {
        guard let selectedId else { return }
        actions.paste(selectedId)
    }

    public func close() {
        actions.close()
    }
}
