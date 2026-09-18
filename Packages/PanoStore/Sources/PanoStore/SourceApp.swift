import Foundation
import GRDB

/// One source app for the panel's rail: the apps clips were copied from, most recently used first.
public struct SourceApp: Codable, Sendable, Identifiable, Equatable, FetchableRecord {
    public var bundleId: String
    public var name: String?
    public var clipCount: Int
    public var id: String { bundleId }

    enum CodingKeys: String, CodingKey {
        case bundleId = "source_bundle_id"
        case name = "source_name"
        case clipCount = "clip_count"
    }
}
