import Foundation
import GRDB

/// An app Pano never records copies from (a privacy control). v1 excludes every kind; the
/// `excluded_kinds` column stays NULL until per-kind exclusion is offered.
public struct ExcludedApp: Codable, Sendable, Identifiable, FetchableRecord, PersistableRecord {
    public var bundleId: String
    public var displayName: String

    public var id: String { bundleId }

    public init(bundleId: String, displayName: String) {
        self.bundleId = bundleId
        self.displayName = displayName
    }

    public static let databaseTableName = "excluded_app"

    enum CodingKeys: String, CodingKey {
        case bundleId = "bundle_id"
        case displayName = "display_name"
    }
}
