import Foundation

/// What the capture loop hands the store for one copy: the representations in
/// pasteboard order plus the metadata the loop already worked out. The store
/// computes the hash, the retention deadline, and the inline/blob split.
public struct ClipCapture: Sendable {
    public var kind: Clip.Kind
    public var content: String?
    public var representations: [Representation]
    public var sourceBundleId: String?
    public var sourceName: String?
    public var language: String?
    public var sensitivity: Clip.Sensitivity
    public var isMasked: Bool

    public struct Representation: Sendable {
        public var uti: String
        public var data: Data
        public init(uti: String, data: Data) {
            self.uti = uti
            self.data = data
        }
    }

    public init(
        kind: Clip.Kind,
        content: String?,
        representations: [Representation],
        sourceBundleId: String? = nil,
        sourceName: String? = nil,
        language: String? = nil,
        sensitivity: Clip.Sensitivity = .none,
        isMasked: Bool = false
    ) {
        self.kind = kind
        self.content = content
        self.representations = representations
        self.sourceBundleId = sourceBundleId
        self.sourceName = sourceName
        self.language = language
        self.sensitivity = sensitivity
        self.isMasked = isMasked
    }
}
