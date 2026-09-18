import Foundation

/// A small, dependency-free syntax highlighter for the preview (ADR: no third-party highlighter).
/// It tokenises with regexes into a handful of classes and covers the languages most often copied.
/// Glance quality, not editor quality.
public enum CodeHighlighter {
    public enum Language: String, Sendable, CaseIterable {
        case swift, javascript, python, json, shell, html, css, java, sql
    }

    public enum TokenKind: Sendable, Equatable {
        case keyword, string, comment, number
    }

    /// A highlighted region, as a UTF-16 offset and length (matches `NSRange`, for AttributedString).
    public struct Span: Sendable, Equatable {
        public let start: Int
        public let length: Int
        public let kind: TokenKind
    }

    public static func spans(for code: String, language: Language) -> [Span] {
        let spec = spec(for: language)
        let ns = code as NSString
        var claimed = [Bool](repeating: false, count: ns.length)
        var spans: [Span] = []

        func add(_ pattern: String, _ kind: TokenKind, options: NSRegularExpression.Options = []) {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return }
            for match in regex.matches(in: code, range: NSRange(location: 0, length: ns.length)) {
                let r = match.range
                guard r.length > 0, r.location != NSNotFound else { continue }
                if (r.location..<r.location + r.length).contains(where: { claimed[$0] }) { continue }
                for i in r.location..<r.location + r.length { claimed[i] = true }
                spans.append(Span(start: r.location, length: r.length, kind: kind))
            }
        }

        // Comments and strings first so keywords inside them are not re-coloured.
        if let (open, close) = spec.blockComment {
            add("\(esc(open))[\\s\\S]*?\(esc(close))", .comment)
        }
        if let line = spec.lineComment {
            add("\(esc(line)).*", .comment)
        }
        for delim in spec.stringDelimiters {
            let q = esc(String(delim))
            add("\(q)(?:\\\\.|[^\(q)\\\\])*\(q)", .string)
        }
        add("\\b\\d+(?:\\.\\d+)?\\b", .number)
        if !spec.keywords.isEmpty {
            let alt = spec.keywords.map { NSRegularExpression.escapedPattern(for: $0) }.joined(separator: "|")
            add("\\b(?:\(alt))\\b", .keyword, options: spec.caseInsensitiveKeywords ? [.caseInsensitive] : [])
        }
        return spans.sorted { $0.start < $1.start }
    }

    /// Best-effort language guess from the code's shape. nil when nothing matches (render plain).
    public static func detectLanguage(_ code: String) -> Language? {
        let t = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return nil }
        if t.hasPrefix("#!"), t.contains("sh") { return .shell }
        if (t.hasPrefix("{") || t.hasPrefix("[")),
            (try? JSONSerialization.jsonObject(with: Data(t.utf8))) != nil
        {
            return .json
        }
        if t.contains("<html") || t.contains("</")
            || t.range(of: "<[a-zA-Z]+[^>]*>", options: .regularExpression) != nil
        {
            return .html
        }
        let lower = t.lowercased()
        if ["select ", "insert into", "update ", "delete from", " from ", " where ", " join "]
            .filter({ lower.contains($0) }).count >= 2
        {
            return .sql
        }
        var score: [Language: Int] = [:]
        func bump(_ l: Language, _ patterns: [String]) {
            score[l, default: 0] += patterns.filter { t.contains($0) }.count
        }
        bump(.swift, ["func ", "let ", "var ", "guard ", "-> ", "import Foundation", "@State", "struct ", "enum "])
        bump(.javascript, ["function ", "const ", "=>", "console.", "var ", "let ", "document.", "export "])
        bump(.python, ["def ", "import ", "print(", "elif ", "self.", "lambda ", "__name__"])
        bump(.shell, ["echo ", "$(", "fi\n", "then\n", "export ", "sudo ", "#!/"])
        bump(.css, ["{\n", "px;", "margin:", "color:", "display:", "font-"])
        bump(
            .java,
            [
                "public ", "private ", "protected ", ".class", "import ", "new ", "void ",
                "System.", "@Override", "String ", "Long ", "Integer ", "boolean ", "class ",
                "interface ", "extends ", "implements ",
            ]
        )
        guard let best = score.max(by: { $0.value < $1.value }), best.value >= 2 else { return nil }
        return best.key
    }

    // MARK: language specs

    private struct Spec {
        var keywords: Set<String>
        var lineComment: String?
        var blockComment: (String, String)?
        var stringDelimiters: [Character]
        var caseInsensitiveKeywords = false
    }

    private static func esc(_ s: String) -> String { NSRegularExpression.escapedPattern(for: s) }

    private static func spec(for language: Language) -> Spec {
        switch language {
        case .swift:
            return Spec(
                keywords: [
                    "func", "let", "var", "if", "else", "guard", "return", "struct", "class", "enum",
                    "import", "public", "private", "internal", "static", "self", "init", "for", "in",
                    "while", "switch", "case", "default", "throws", "try", "await", "async", "extension",
                    "protocol", "some", "nil", "true", "false",
                ],
                lineComment: "//", blockComment: ("/*", "*/"), stringDelimiters: ["\""])
        case .javascript:
            return Spec(
                keywords: [
                    "function", "const", "let", "var", "if", "else", "return", "class", "import",
                    "export", "for", "while", "switch", "case", "default", "await", "async", "new",
                    "this", "null", "undefined", "true", "false", "typeof",
                ],
                lineComment: "//", blockComment: ("/*", "*/"), stringDelimiters: ["\"", "'", "`"])
        case .python:
            return Spec(
                keywords: [
                    "def", "class", "import", "from", "if", "elif", "else", "return", "for", "while",
                    "in", "not", "and", "or", "None", "True", "False", "lambda", "with", "as", "try",
                    "except", "self", "print",
                ],
                lineComment: "#", blockComment: nil, stringDelimiters: ["\"", "'"])
        case .json:
            return Spec(
                keywords: ["true", "false", "null"], lineComment: nil, blockComment: nil, stringDelimiters: ["\""])
        case .shell:
            return Spec(
                keywords: [
                    "if", "then", "fi", "for", "in", "do", "done", "echo", "export", "case", "esac", "function",
                ],
                lineComment: "#", blockComment: nil, stringDelimiters: ["\"", "'"])
        case .html:
            return Spec(keywords: [], lineComment: nil, blockComment: ("<!--", "-->"), stringDelimiters: ["\"", "'"])
        case .css:
            return Spec(
                keywords: ["important", "px", "em", "rem", "auto", "none", "flex", "block", "inline"],
                lineComment: nil, blockComment: ("/*", "*/"), stringDelimiters: ["\"", "'"])
        case .java:
            return Spec(
                keywords: [
                    "public", "private", "protected", "class", "interface", "void", "static", "final",
                    "new", "return", "if", "else", "for", "while", "switch", "case", "default", "import",
                    "package", "extends", "implements", "this", "null", "true", "false", "int", "boolean",
                    "String", "throws", "try", "catch",
                ],
                lineComment: "//", blockComment: ("/*", "*/"), stringDelimiters: ["\""])
        case .sql:
            return Spec(
                keywords: [
                    "select", "from", "where", "insert", "into", "values", "update", "set", "delete",
                    "join", "inner", "left", "right", "outer", "on", "group", "by", "order", "having",
                    "limit", "and", "or", "not", "null", "as", "distinct", "count", "create", "table",
                ],
                lineComment: "--", blockComment: ("/*", "*/"), stringDelimiters: ["'", "\""],
                caseInsensitiveKeywords: true)
        }
    }
}
