import AppKit
import Foundation
import PanoStore

/// Polls the general pasteboard's `changeCount` and records new copies (docs/02-architecture.md).
/// There is no change notification API, so a 0.5 s timer is the mechanism; idle cost is a single
/// integer read and no entitlement is required.
public actor CaptureEngine {
    private let store: Store
    private let interval: Duration
    private var excludedBundleIds: Set<String>
    private var lastChangeCount: Int
    private var task: Task<Void, Never>?

    public init(
        store: Store,
        excludedBundleIds: Set<String> = [],
        interval: Duration = .milliseconds(500)
    ) {
        self.store = store
        self.excludedBundleIds = excludedBundleIds
        self.interval = interval
        self.lastChangeCount = NSPasteboard.general.changeCount
    }

    public func setExcludedBundleIds(_ ids: Set<String>) {
        excludedBundleIds = ids
    }

    public func start() {
        guard task == nil else { return }
        task = Task { [weak self] in
            while !Task.isCancelled {
                await self?.tick()
                try? await Task.sleep(for: self?.interval ?? .milliseconds(500))
            }
        }
    }

    public func stop() {
        task?.cancel()
        task = nil
    }

    /// One poll: returns the inserted clip id when a new copy was recorded, nil otherwise.
    /// Exposed so a test can drive a single tick deterministically instead of waiting on the timer.
    @discardableResult
    public func tick() async -> Int64? {
        let pb = NSPasteboard.general
        let change = pb.changeCount
        guard change != lastChangeCount else { return nil }
        lastChangeCount = change

        guard let input = Self.read(pb) else { return nil }
        if let bundle = input.sourceBundleId, excludedBundleIds.contains(bundle) { return nil }
        guard let capture = CaptureBuilder.build(input) else { return nil }
        return try? await store.insert(capture)
    }

    /// Reads the current pasteboard into a plain value. Flattens every item's representations into
    /// one ordered list (Maccy merges multi-item copies the same way); marker/whitelist filtering
    /// happens in CaptureBuilder.
    private static func read(_ pb: NSPasteboard) -> CaptureBuilder.Input? {
        guard let items = pb.pasteboardItems else { return nil }
        var utis: [String] = []
        var data: [String: Data] = [:]
        for item in items {
            for type in item.types {
                let uti = type.rawValue
                if data[uti] == nil, let bytes = item.data(forType: type) {
                    utis.append(uti)
                    data[uti] = bytes
                }
            }
        }
        guard !utis.isEmpty else { return nil }

        let app = NSWorkspace.shared.frontmostApplication
        return CaptureBuilder.Input(
            utis: utis, data: data,
            sourceBundleId: app?.bundleIdentifier, sourceName: app?.localizedName
        )
    }
}
