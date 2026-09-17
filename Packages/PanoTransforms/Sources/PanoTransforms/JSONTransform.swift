import Foundation

/// Pretty-prints JSON with sorted keys. Offered only when the text actually parses as JSON.
public struct JSONTransform: Transform {
    public let id = "json"
    public let title = "JSON"
    public init() {}

    public func applies(to text: String) -> Bool {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = t.first, first == "{" || first == "[" else { return false }
        return (try? JSONSerialization.jsonObject(with: Data(t.utf8))) != nil
    }

    public func apply(_ input: String) throws -> TransformOutput {
        let data = Data(input.trimmingCharacters(in: .whitespacesAndNewlines).utf8)
        let object = try JSONSerialization.jsonObject(with: data)
        let pretty = try JSONSerialization.data(
            withJSONObject: object, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
        return TransformOutput(String(decoding: pretty, as: UTF8.self))
    }
}
