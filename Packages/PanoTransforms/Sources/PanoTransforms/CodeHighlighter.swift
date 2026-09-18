import Foundation

/// Language detection for copied code: drives the row's language label and hints the renderer.
/// Rendering itself is done by Highlightr in PanoUI (ADR 0007); this stays dependency-free so
/// PanoTransforms keeps depending on nothing.
public enum CodeHighlighter {
    public enum Language: String, Sendable, CaseIterable {
        case swift, javascript, python, json, shell, html, css, java, sql
    }

    /// Best-effort language guess from the code's shape. nil when nothing matches.
    public static func detectLanguage(_ code: String) -> Language? {
        let t = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return nil }
        if t.hasPrefix("#!"), t.contains("sh") { return .shell }
        if (t.hasPrefix("{") || t.hasPrefix("[")),
            (try? JSONSerialization.jsonObject(with: Data(t.utf8))) != nil
        {
            return .json
        }
        let lower = t.lowercased()
        if ["select ", "insert into", "update ", "delete from", " from ", " where ", " join "]
            .filter({ lower.contains($0) }).count >= 2
        {
            return .sql
        }
        var score: [Language: Int] = [:]
        func bump(_ language: Language, _ patterns: [String]) {
            score[language, default: 0] += patterns.filter { t.contains($0) }.count
        }
        bump(.swift, ["func ", "let ", "var ", "guard ", "-> ", "import Foundation", "@State", "struct ", "enum "])
        bump(.javascript, ["function ", "const ", "=>", "console.", "var ", "let ", "document.", "export "])
        bump(.python, ["def ", "import ", "print(", "elif ", "self.", "lambda ", "__name__"])
        bump(.shell, ["echo ", "$(", "fi\n", "then\n", "export ", "sudo ", "#!/"])
        bump(.css, ["{\n", "px;", "margin:", "color:", "display:", "font-"])
        bump(
            .html,
            [
                "<!doctype", "<html", "<head", "<body", "<div", "</div>", "<span", "</span>",
                "<a href", "<p>", "</p>", "<img", "<script", "<ul>", "<li>", "<link ", "<meta ",
            ]
        )
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
}
