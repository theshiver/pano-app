import Foundation
import PanoStore

/// Turns a raw pasteboard read into a `ClipCapture`, or nil when nothing should be recorded.
/// Pure and synchronous so the whole classification path is unit-testable without a real
/// pasteboard. The engine (CaptureEngine) does the AppKit reading and calls this.
public enum CaptureBuilder {
    public struct Input: Sendable {
        public var utis: [String]  // in pasteboard preference order, may include non-whitelisted
        public var data: [String: Data]
        public var sourceBundleId: String?
        public var sourceName: String?

        public init(
            utis: [String], data: [String: Data], sourceBundleId: String? = nil, sourceName: String? = nil
        ) {
            self.utis = utis
            self.data = data
            self.sourceBundleId = sourceBundleId
            self.sourceName = sourceName
        }
    }

    /// Returns nil when the copy carries a concealed/transient marker, or when no whitelisted
    /// representation is present (nothing worth storing).
    /// `maskSecrets` off (Settings) stores secrets like any other text: no masking, normal retention.
    public static func build(_ input: Input, maskSecrets: Bool = true) -> ClipCapture? {
        let present = Set(input.utis)
        if !present.isDisjoint(with: PasteboardUTIs.markers) { return nil }

        var reps: [ClipCapture.Representation] = []
        var keptUTIs = Set<String>()
        for uti in input.utis where PasteboardUTIs.whitelist.contains(uti) && !keptUTIs.contains(uti) {
            guard let data = input.data[uti] else { continue }
            // PNG wins over TIFF: drop TIFF when a PNG is also present (docs/03-data-model.md).
            if uti == PasteboardUTIs.tiff && present.contains(PasteboardUTIs.png) { continue }
            reps.append(.init(uti: uti, data: data))
            keptUTIs.insert(uti)
        }
        guard !reps.isEmpty else { return nil }

        let text = input.data[PasteboardUTIs.plainText].flatMap { String(data: $0, encoding: .utf8) }
        let kind = ClipClassifier.kind(utis: keptUTIs, text: text)
        let sensitivity = maskSecrets ? SensitiveScanner.classify(text) : .none

        return ClipCapture(
            kind: kind,
            content: text,
            representations: reps,
            sourceBundleId: input.sourceBundleId,
            sourceName: input.sourceName,
            language: nil,
            sensitivity: sensitivity,
            isMasked: sensitivity != .none
        )
    }
}
