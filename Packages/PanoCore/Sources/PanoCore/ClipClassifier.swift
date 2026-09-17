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
        if utis.contains(PasteboardUTIs.png) || utis.contains(PasteboardUTIs.tiff) { return .image }
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

    /// The whole string is a single http/https/ftp/mailto URL with a host, no embedded whitespace.
    static func isURL(_ text: String) -> Bool {
        guard !text.contains(where: \.isWhitespace), let url = URL(string: text) else { return false }
        guard let scheme = url.scheme?.lowercased() else { return false }
        if scheme == "mailto" { return url.absoluteString.contains("@") }
        return ["http", "https", "ftp"].contains(scheme) && (url.host?.isEmpty == false)
    }
}
