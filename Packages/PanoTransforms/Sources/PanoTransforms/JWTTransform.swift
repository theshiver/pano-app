import Foundation

/// Decodes a JWT into its header and payload JSON. Offered only for a real three-part token.
public struct JWTTransform: Transform {
    public let id = "jwt"
    public let title = "JWT"
    public init() {}

    public func applies(to text: String) -> Bool {
        parts(of: text) != nil
    }

    public func apply(_ input: String) throws -> TransformOutput {
        guard let (header, payload) = parts(of: input) else { throw TransformError.notApplicable }
        return TransformOutput("// header\n\(header)\n\n// payload\n\(payload)")
    }

    private func parts(of text: String) -> (header: String, payload: String)? {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let segments = t.split(separator: ".", omittingEmptySubsequences: false)
        guard segments.count == 3, segments.allSatisfy({ !$0.isEmpty }) else { return nil }
        guard let header = prettyJSON(String(segments[0])), header.contains("alg"),
            let payload = prettyJSON(String(segments[1]))
        else { return nil }
        return (header, payload)
    }

    private func prettyJSON(_ base64url: String) -> String? {
        var b = base64url.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while b.count % 4 != 0 { b += "=" }
        guard let data = Data(base64Encoded: b), let object = try? JSONSerialization.jsonObject(with: data),
            let pretty = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
        else { return nil }
        return String(decoding: pretty, as: UTF8.self)
    }
}
