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
    private var paused = false
    private var ocrEnabled = false

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

    /// While paused, the loop keeps running but records nothing; new copies are ignored until
    /// resumed. Resuming does not back-fill what was copied while paused.
    public func setPaused(_ value: Bool) {
        paused = value
        if value { lastChangeCount = NSPasteboard.general.changeCount }
    }

    public var isPaused: Bool { paused }

    /// OCR runs only when enabled (Settings; off by default because the first Vision request is
    /// expensive). Toggling it does not re-scan existing clips.
    public func setOCREnabled(_ value: Bool) {
        ocrEnabled = value
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
        guard !paused else { return nil }
        let pb = NSPasteboard.general
        let change = pb.changeCount
        guard change != lastChangeCount else { return nil }
        lastChangeCount = change

        guard let input = Self.read(pb) else { return nil }
        if let bundle = input.sourceBundleId, excludedBundleIds.contains(bundle) { return nil }
        guard let capture = CaptureBuilder.build(input) else { return nil }
        guard let id = try? await store.insert(capture) else { return nil }
        scheduleOCR(for: capture, id: id)
        return id
    }

    /// Kicks OCR onto a detached task for image clips and writes the recognised text back through
    /// the store, so screenshots become searchable without blocking the capture loop.
    private func scheduleOCR(for capture: ClipCapture, id: Int64) {
        guard ocrEnabled else { return }
        let imageData = capture.representations.first { PasteboardUTIs.imageUTIs.contains($0.uti) }?.data
        guard let imageData else { return }
        let store = store
        Task.detached(priority: .utility) {
            guard let text = await OCRService.recognizeText(in: imageData) else { return }
            try? await store.setOCRText(text, id: id)
        }
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
        // A Finder file copy carries only a file URL, the name and an icon — no bitmap. If the file
        // is an image, read it through the pasteboard's security-scoped URL (a plain URL from the
        // file-url bytes is not sandbox-accessible) and add a PNG so it previews and pastes as an
        // image, not just as a file.
        if data.keys.allSatisfy({ !PasteboardUTIs.imageUTIs.contains($0) }),
            let (uti, bytes) = Self.imageBytesFromFileURLs(on: pb)
        {
            utis.append(uti)
            data[uti] = bytes
        }

        guard !utis.isEmpty else { return nil }

        let app = NSWorkspace.shared.frontmostApplication
        return CaptureBuilder.Input(
            utis: utis, data: data,
            sourceBundleId: app?.bundleIdentifier, sourceName: app?.localizedName
        )
    }

    private static let imageExtensions: Set<String> = [
        "jpg", "jpeg", "png", "gif", "heic", "heif", "tiff", "tif", "bmp", "webp",
    ]

    private static func isImageFile(_ url: URL) -> Bool {
        imageExtensions.contains(url.pathExtension.lowercased())
    }

    /// Reads the raw bytes of the first image file among the pasteboard's file URLs, through the
    /// security-scoped resource so the sandbox grants access. No decode/re-encode — a large JPG is
    /// stored as-is (fast, small), and only decoded lazily by the preview when it is selected.
    private static func imageBytesFromFileURLs(on pb: NSPasteboard) -> (uti: String, data: Data)? {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        guard let urls = pb.readObjects(forClasses: [NSURL.self], options: options) as? [URL],
            let url = urls.first(where: isImageFile),
            let uti = imageUTI(for: url)
        else { return nil }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let bytes = try? Data(contentsOf: url) else { return nil }
        return (uti, bytes)
    }

    private static func imageUTI(for url: URL) -> String? {
        switch url.pathExtension.lowercased() {
        case "jpg", "jpeg": return "public.jpeg"
        case "png": return "public.png"
        case "gif": return "com.compuserve.gif"
        case "heic", "heif": return "public.heic"
        case "tiff", "tif": return "public.tiff"
        default: return nil  // bmp/webp: skip until they earn a UTI mapping
        }
    }
}
