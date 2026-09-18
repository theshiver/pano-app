import Foundation

/// Strips Markdown to plain text — for pasting a `.md` snippet into Slack, mail or a form without the
/// `#`, `**` and `[link](url)` noise. Parsing is Foundation's own Markdown support; nothing is
/// rendered, only the markup is dropped. Offered when the text contains block or inline markup.
public struct MarkdownTransform: Transform {
    public let id = "markdown"
    public let title = "Markdown"
    public init() {}

    // Block markers at line start, or inline emphasis/code/link markers.
    private static let markup =
        #"(?m)^\s{0,3}(#{1,6}\s|[-*+]\s|\d+\.\s|>\s?|```)|\*\*|__|`[^`\n]+`|\[[^\]\n]+\]\([^)\n]+\)"#

    public func applies(to text: String) -> Bool {
        text.range(of: Self.markup, options: .regularExpression) != nil
    }

    public func apply(_ input: String) throws -> TransformOutput {
        guard applies(to: input) else { throw TransformError.notApplicable }
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .full, failurePolicy: .returnPartiallyParsedIfPossible)
        guard let parsed = try? AttributedString(markdown: input, options: options) else {
            throw TransformError.notApplicable
        }
        // Full syntax drops the newlines between blocks; put one back wherever the block intent changes.
        var text = ""
        var block: PresentationIntent?
        for run in parsed.runs {
            if !text.isEmpty, run.presentationIntent != block { text += "\n" }
            block = run.presentationIntent
            text += String(parsed[run.range].characters)
        }
        return TransformOutput(text.trimmingCharacters(in: .newlines))
    }
}
