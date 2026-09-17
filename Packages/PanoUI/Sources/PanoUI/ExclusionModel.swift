import Foundation
import PanoStore

/// Backs the "Excluded apps" section of Settings. The list is loaded from the store by the app,
/// and add/remove are injected closures the app implements (picking an app, writing to the store,
/// updating the capture engine), so PanoUI stays free of AppKit and the store.
@MainActor
@Observable
public final class ExclusionModel {
    public var apps: [ExcludedApp] = []
    private let onAdd: () -> Void
    private let onRemove: (String) -> Void

    public init(onAdd: @escaping () -> Void, onRemove: @escaping (String) -> Void) {
        self.onAdd = onAdd
        self.onRemove = onRemove
    }

    public func add() { onAdd() }
    public func remove(_ bundleId: String) { onRemove(bundleId) }
}
