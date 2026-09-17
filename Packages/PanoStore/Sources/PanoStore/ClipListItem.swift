import Foundation
import GRDB

/// The columns the panel's row actually renders. The list and search queries fetch only these,
/// never `SELECT *` (docs/03-data-model.md): the full `Clip` and its representations are loaded
/// on demand when an item is selected.
public struct ClipListItem: Codable, Sendable, Identifiable, FetchableRecord {
    public var id: Int64
    public var kind: Clip.Kind
    public var content: String?
    public var sourceBundleId: String?
    public var sourceName: String?
    public var isPinned: Bool
    public var isMasked: Bool
    public var sensitivity: Clip.Sensitivity
    public var copyCount: Int
    public var lastSeenAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case kind
        case content
        case sourceBundleId = "source_bundle_id"
        case sourceName = "source_name"
        case isPinned = "is_pinned"
        case isMasked = "is_masked"
        case sensitivity
        case copyCount = "copy_count"
        case lastSeenAt = "last_seen_at"
    }

    static let columns =
        "clip.id, clip.kind, clip.content, clip.source_bundle_id, clip.source_name, "
        + "clip.is_pinned, clip.is_masked, clip.sensitivity, clip.copy_count, clip.last_seen_at"
}
