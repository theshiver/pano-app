import Foundation

/// A pure, synchronous conversion offered in the preview's transform bar (docs/02-architecture.md).
/// `applies(to:)` decides whether the chip is even shown; `apply` produces the result.
public protocol Transform: Sendable {
    var id: String { get }  // "json", "b64", "colour"
    var title: String { get }  // chip label
    func applies(to text: String) -> Bool
    func apply(_ input: String) throws -> TransformOutput
}

/// Most transforms return a single `text`. Colour also returns a list of named `formats`, each
/// selectable and pasteable on its own (docs/05-design.md).
public struct TransformOutput: Sendable, Equatable {
    public var text: String
    public var formats: [Format]

    public init(_ text: String, formats: [Format] = []) {
        self.text = text
        self.formats = formats
    }

    public struct Format: Sendable, Equatable, Identifiable {
        public var label: String
        public var value: String
        public var id: String { label }
        public init(_ label: String, _ value: String) {
            self.label = label
            self.value = value
        }
    }
}

public enum TransformError: Error, Equatable {
    case notApplicable
}

/// The registry the transform bar uses. `markdown` is intentionally absent until its behaviour is
/// specified (the docs list it in the bar but do not define what it does).
public enum Transforms {
    public static let all: [any Transform] = [
        JSONTransform(), Base64Transform(), JWTTransform(),
        URLTransform(), SlugTransform(), CleanTransform(), ColourTransform(),
    ]

    /// The transforms whose chip should appear for this text, in bar order.
    public static func applicable(to text: String) -> [any Transform] {
        all.filter { $0.applies(to: text) }
    }
}
