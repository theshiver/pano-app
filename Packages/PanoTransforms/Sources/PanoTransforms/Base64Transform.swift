import Foundation

/// Decodes base64 text to UTF-8. Offered only when the text is valid base64 that decodes to
/// readable text (so it does not show for arbitrary strings).
public struct Base64Transform: Transform {
    public let id = "b64"
    public let title = "Base64"
    public init() {}

    public func applies(to text: String) -> Bool {
        decoded(from: text) != nil
    }

    public func apply(_ input: String) throws -> TransformOutput {
        guard let text = decoded(from: input) else { throw TransformError.notApplicable }
        return TransformOutput(text)
    }

    private func decoded(from text: String) -> String? {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard t.count >= 8, t.count % 4 == 0 else { return nil }
        let charset = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=")
        guard t.unicodeScalars.allSatisfy(charset.contains) else { return nil }
        guard let data = Data(base64Encoded: t), let string = String(data: data, encoding: .utf8),
            !string.isEmpty, string != t
        else { return nil }
        // Require the decoded text to be mostly printable, so random base64-looking IDs don't match.
        let printable = string.unicodeScalars.filter {
            !$0.properties.isDefaultIgnorableCodePoint && ($0.value >= 32 || $0 == "\n" || $0 == "\t")
        }
        return Double(printable.count) / Double(string.unicodeScalars.count) > 0.9 ? string : nil
    }
}
