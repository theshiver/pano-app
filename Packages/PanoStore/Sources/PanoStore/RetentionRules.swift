import Foundation

/// Default retention windows (docs/03-data-model.md). User-editable in Settings later;
/// week 1 only needs the infrastructure, so these are the built-in defaults.
public struct RetentionRules: Sendable {
    public var secret: TimeInterval = 60 * 60  // 1 hour
    public var image: TimeInterval = 7 * 24 * 60 * 60  // 7 days
    public var other: TimeInterval = 30 * 24 * 60 * 60  // 30 days

    public init() {}

    /// Pinned clips never expire; that is applied at query/pin time, not here.
    public func expiry(for capture: ClipCapture, from now: Date) -> Date {
        let window: TimeInterval
        if capture.sensitivity != .none {
            window = secret
        } else if capture.kind == .image {
            window = image
        } else {
            window = other
        }
        return now.addingTimeInterval(window)
    }
}
