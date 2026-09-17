import Foundation
import GRDB

/// One pasteboard representation of a `Clip`, in the source app's preference order.
/// Small representations live inline in `data`; large binaries are written to a file
/// under `Blobs/` and referenced by `blobPath`. Exactly one of the two is non-nil.
public struct ClipContent: Codable, Sendable, FetchableRecord, PersistableRecord {
    public var clipId: Int64
    public var position: Int
    public var uti: String
    public var data: Data?
    public var blobPath: String?
    public var byteSize: Int

    enum CodingKeys: String, CodingKey {
        case clipId = "clip_id"
        case position
        case uti
        case data
        case blobPath = "blob_path"
        case byteSize = "byte_size"
    }

    public static let databaseTableName = "clip_content"

    /// Representations at or above this size go to disk instead of the row.
    public static let inlineThreshold = 64 * 1024
}
