import Foundation

/// Percent-decodes a URL when it contains encoded octets, otherwise percent-encodes it. Offered for
/// URL-ish strings and anything already containing `%XX`.
public struct URLTransform: Transform {
    public let id = "url"
    public let title = "URL"
    public init() {}

    public func applies(to text: String) -> Bool {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, !t.contains(where: \.isNewline) else { return false }
        if containsPercentEscape(t) { return true }
        return t.contains("://") && t.rangeOfCharacter(from: Self.needsEncoding) != nil
    }

    public func apply(_ input: String) throws -> TransformOutput {
        let t = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if containsPercentEscape(t) {
            return TransformOutput(t.removingPercentEncoding ?? t)
        }
        let encoded = t.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? t
        return TransformOutput(encoded)
    }

    private static let needsEncoding = CharacterSet(charactersIn: " \"<>{}|\\^`").union(.whitespaces)

    private func containsPercentEscape(_ text: String) -> Bool {
        guard let range = text.range(of: "%[0-9A-Fa-f]{2}", options: .regularExpression) else { return false }
        return !range.isEmpty
    }
}
