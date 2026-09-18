import Foundation
import PanoStore

/// Decides a clip's `kind` from the representations present and the text, in the priority
/// order fixed by docs/02-architecture.md: colour → url → file → image → rich text → plain text.
public enum ClipClassifier {
    public static func kind(utis: Set<String>, text: String?) -> Clip.Kind {
        let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines)

        if let trimmed, isColour(trimmed) { return .colour }
        if let trimmed, isURL(trimmed) { return .url }
        if utis.contains(PasteboardUTIs.fileURL) { return .file }
        if !utis.isDisjoint(with: PasteboardUTIs.imageUTIs) { return .image }
        // Code detection comes before rich text: editors and IDEs put RTF/HTML on the pasteboard
        // alongside the plain code, so checking richtext first would hide every copied snippet.
        if let trimmed, isMarkdown(trimmed) || isCode(trimmed) { return .code }
        if utis.contains(PasteboardUTIs.rtf) || utis.contains(PasteboardUTIs.html) { return .richtext }
        return .text
    }

    /// Hex (`#rgb`, `#rrggbb`, `#rrggbbaa`) or a `rgb()/rgba()/hsl()/hsla()` function. A minimal
    /// check; the full colour transform (weeks 5–6) parses more, but the kind only needs this.
    static func isColour(_ text: String) -> Bool {
        if let first = text.first, first == "#" {
            let body = text.dropFirst()
            let lengths: Set<Int> = [3, 4, 6, 8]
            return lengths.contains(body.count) && body.allSatisfy(\.isHexDigit)
        }
        let lower = text.lowercased()
        for fn in ["rgb(", "rgba(", "hsl(", "hsla("] where lower.hasPrefix(fn) && lower.hasSuffix(")") {
            return true
        }
        return false
    }

    /// Raw Markdown source (a README, a brief): two or more lines opening with a heading, list, quote
    /// or fence marker. Checked before code because prose about code trips the code signals.
    static func isMarkdown(_ text: String) -> Bool {
        text.ranges(of: /(?m)^ {0,3}(#{1,6} |[-*+] |\d+\. |> |```)/).count >= 2
    }

    /// Conservative code detection: strong structural signals so ordinary prose is not misclassified.
    /// JSON is left as text (its transform handles it); this is for source snippets.
    static func isCode(_ text: String) -> Bool {
        guard text.count >= 12 else { return false }
        if text.hasPrefix("#!") { return true }
        if (text.hasPrefix("{") || text.hasPrefix("[")),
            (try? JSONSerialization.jsonObject(with: Data(text.utf8))) != nil
        {
            return false  // data, not code
        }
        let signals = [
            "function ", "=>", "const ", "let ", "var ", "def ", "func ", "class ", "import ",
            "#include", "public ", "private ", "return ", "</", "/>", "() {", ") {", "){", "};",
        ]
        var hits = signals.filter { text.contains($0) }.count
        let lower = text.lowercased()
        // A statement keyword at line start plus a clause word; substring matches alone hit ordinary prose.
        if lower.contains(/(?m)^\s*(select|insert into|update|delete from)\b/),
            lower.contains(/\s(from|where|set|values)\s/)
        {
            hits += 2
        }
        let codeyLines = text.split(separator: "\n").filter {
            let l = $0.trimmingCharacters(in: .whitespaces)
            return l.hasSuffix(";") || l.hasSuffix("{") || l.hasSuffix("}")
        }.count
        return hits >= 2 || (hits >= 1 && codeyLines >= 1) || codeyLines >= 3
    }

    /// The whole string is a single http/https/ftp/mailto URL with a host, no embedded whitespace.
    static func isURL(_ text: String) -> Bool {
        guard !text.contains(where: \.isWhitespace), let url = URL(string: text) else { return false }
        guard let scheme = url.scheme?.lowercased() else { return false }
        if scheme == "mailto" { return url.absoluteString.contains("@") }
        return ["http", "https", "ftp"].contains(scheme) && (url.host?.isEmpty == false)
    }
}
