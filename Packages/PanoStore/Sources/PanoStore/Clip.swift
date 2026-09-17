import Foundation
import GRDB

/// One clipboard entry: metadata plus its representations (`ClipContent`).
/// See docs/03-data-model.md for the schema and the reasoning.
public struct Clip: Codable, Sendable, Identifiable, FetchableRecord, MutablePersistableRecord {
    public var id: Int64?
    public var kind: Kind
    public var content: String?
    public var byteSize: Int
    public var contentHash: String
    public var sourceBundleId: String?
    public var sourceName: String?
    public var language: String?
    public var ocrText: String?
    public var isPinned: Bool
    public var isMasked: Bool
    public var sensitivity: Sensitivity
    public var copyCount: Int
    public var createdAt: Date
    public var lastSeenAt: Date
    public var expiresAt: Date?

    public enum Kind: String, Codable, Sendable {
        case text, richtext, code, url, colour, image, file
    }

    public enum Sensitivity: String, Codable, Sendable {
        case none, secret, financial
    }

    enum CodingKeys: String, CodingKey {
        case id
        case kind
        case content
        case byteSize = "byte_size"
        case contentHash = "content_hash"
        case sourceBundleId = "source_bundle_id"
        case sourceName = "source_name"
        case language
        case ocrText = "ocr_text"
        case isPinned = "is_pinned"
        case isMasked = "is_masked"
        case sensitivity
        case copyCount = "copy_count"
        case createdAt = "created_at"
        case lastSeenAt = "last_seen_at"
        case expiresAt = "expires_at"
    }

    public static let databaseTableName = "clip"

    public enum Columns {
        static let id = Column("id")
        static let contentHash = Column("content_hash")
        static let lastSeenAt = Column("last_seen_at")
        static let expiresAt = Column("expires_at")
    }

    public mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
