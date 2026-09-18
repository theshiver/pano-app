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
/// selectable and pasteable on its own (docs/05-design.md). Markdown adds `html`: the preview renders
/// it and ⏎ pastes it as rich text with `text` as the plain fallback.
public struct TransformOutput: Sendable, Equatable {
    public var text: String
    public var formats: [Format]
    public var html: String?

    public init(_ text: String, formats: [Format] = [], html: String? = nil) {
        self.text = text
        self.formats = formats
        self.html = html
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

/// The registry the transform bar uses, in chip order.
public enum Transforms {
    public static let all: [any Transform] = [
        JSONTransform(), Base64Transform(), JWTTransform(),
        URLTransform(), SlugTransform(), MarkdownTransform(), CleanTransform(), ColourTransform(),
    ]

    /// The transforms whose chip should appear for this text, in bar order.
    public static func applicable(to text: String) -> [any Transform] {
        all.filter { $0.applies(to: text) }
    }
}
