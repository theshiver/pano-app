import Foundation
import GRDB

/// A named, coloured collection of clips (docs/01-product.md: "simple: name, colour, icon").
/// Membership is `pinboard_clip`; a clip on any board is exempt from retention and Clear History.
public struct Pinboard: Codable, Sendable, Identifiable, Equatable, FetchableRecord, PersistableRecord {
    public var id: Int64
    public var name: String
    /// Hex, e.g. "#2A6DF0".
    public var colour: String
    /// SF Symbol name.
    public var icon: String?
    public var sortOrder: Int

    public static let databaseTableName = "pinboard"

    enum CodingKeys: String, CodingKey {
        case id, name, colour, icon
        case sortOrder = "sort_order"
    }
}
