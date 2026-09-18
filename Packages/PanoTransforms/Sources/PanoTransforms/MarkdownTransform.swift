import Foundation

/// Renders Markdown: `html` for the preview and rich paste (Mail, Notes, Slack), `text` as the plain
/// fallback with the markup dropped. Parsing is Foundation's own Markdown support; the walk over
/// its block/inline intents is the only code here. Offered when the text contains block or inline markup.
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
        var html = "", text = ""
        var openLists: [(id: Int, tag: String)] = []
        var lastItem: Int?
        var lastList: Int?
        var block: PresentationIntent? = nil
        var blockRuns: [AttributedString.Runs.Run] = []

        func flush() {
            defer { blockRuns = [] }
            guard !blockRuns.isEmpty else { return }
            // Components are innermost-first; lists are tracked outermost-first.
            let components = block?.components ?? []
            let lists = components.compactMap { c -> (Int, String)? in
                switch c.kind {
                case .unorderedList: return (c.identity, "ul")
                case .orderedList: return (c.identity, "ol")
                default: return nil
                }
            }.reversed()
            let common = zip(openLists, lists).prefix { $0.0.id == $0.1.0 }.count
            for closed in openLists[common...].reversed() { html += "</\(closed.tag)>" }
            openLists.removeLast(openLists.count - common)
            for opened in lists.dropFirst(common) {
                openLists.append(opened)
                html += "<\(opened.1)>"
            }
            let item = components.first { if case .listItem = $0.kind { return true } else { return false } }
            if let item, item.identity != lastItem { html += "<li>" }
            lastItem = item?.identity

            var tag = "p", body = ""
            for c in components {
                switch c.kind {
                case .header(let level): tag = "h\(min(level, 6))"
                case .codeBlock: tag = "pre"
                case .thematicBreak: tag = "hr"
                default: break
                }
            }
            let quoted = components.contains { if case .blockQuote = $0.kind { return true } else { return false } }
            for run in blockRuns {
                var piece = Self.escape(String(parsed[run.range].characters))
                if tag == "pre" {
                    piece = "<code>\(piece)</code>"
                } else {
                    let inline = run.inlinePresentationIntent ?? []
                    if inline.contains(.code) { piece = "<code>\(piece)</code>" }
                    if inline.contains(.emphasized) { piece = "<em>\(piece)</em>" }
                    if inline.contains(.stronglyEmphasized) { piece = "<strong>\(piece)</strong>" }
                    if let link = run.link { piece = "<a href=\"\(Self.escape(link.absoluteString))\">\(piece)</a>" }
                }
                body += piece
            }
            html +=
                tag == "hr"
                ? "<hr>" : "\(quoted ? "<blockquote>" : "")<\(tag)>\(body)</\(tag)>\(quoted ? "</blockquote>" : "")"

            let plain = blockRuns.map { String(parsed[$0.range].characters) }.joined()
            let list = lists.first?.0
            if !text.isEmpty { text += list != nil && list == lastList ? "\n" : "\n\n" }
            text += tag == "hr" ? "—" : plain.trimmingCharacters(in: .newlines)
            lastList = list
        }

        for run in parsed.runs {
            if run.presentationIntent != block {
                flush()
                block = run.presentationIntent
            }
            blockRuns.append(run)
        }
        flush()
        for closed in openLists.reversed() { html += "</\(closed.tag)>" }
        return TransformOutput(text, html: html)
    }

    private static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;").replacingOccurrences(of: "\"", with: "&quot;")
    }
}
