import Foundation

/// Cleans text pasted from PDFs and the web: normalises line endings, removes soft hyphens, collapses
/// runs of spaces, strips trailing whitespace, and caps blank-line runs. Offered only when there is
/// something to clean (docs/01-product.md).
public struct CleanTransform: Transform {
    public let id = "clean"
    public let title = "Clean"
    public init() {}

    public func applies(to text: String) -> Bool {
        text != cleaned(text)
    }

    public func apply(_ input: String) throws -> TransformOutput {
        TransformOutput(cleaned(input))
    }

    private func cleaned(_ text: String) -> String {
        var s = text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        s = s.replacingOccurrences(of: "\u{00AD}", with: "")  // soft hyphen
        s = s.replacingOccurrences(of: "[ \\t]+", with: " ", options: .regularExpression)
        s = s.replacingOccurrences(of: " *\\n", with: "\n", options: .regularExpression)  // trailing spaces
        s = s.replacingOccurrences(of: "\\n{3,}", with: "\n\n", options: .regularExpression)  // blank-line runs
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
