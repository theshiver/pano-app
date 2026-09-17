import Foundation

/// A parsed search string (docs/02-architecture.md). The raw text is turned into this struct and
/// SQL is built from it with bound parameters — user input is never concatenated into SQL.
///
/// - bare words        → FTS5 prefix match over content and OCR text
/// - `app:<x>`         → source bundle id or name contains x
/// - `type:<kind>`     → the clip kind
/// - `pinned:`         → pinned only
/// - `>7d` / `<2h`     → older than / newer than an age (d, h, m)
public struct SearchQuery: Equatable, Sendable {
    public var terms: String = ""
    public var app: String?
    public var kind: Clip.Kind?
    public var pinnedOnly = false
    public var olderThan: TimeInterval?
    public var newerThan: TimeInterval?

    public var hasFilters: Bool {
        app != nil || kind != nil || pinnedOnly || olderThan != nil || newerThan != nil
    }

    public init() {}

    public init(parsing raw: String) {
        var termWords: [String] = []
        for token in raw.split(whereSeparator: \.isWhitespace).map(String.init) {
            if let value = Self.value(token, prefix: "app:") {
                app = value
            } else if let value = Self.value(token, prefix: "type:"), let k = Self.kind(value) {
                kind = k
            } else if token == "pinned:" || token == "pinned:true" {
                pinnedOnly = true
            } else if token.hasPrefix(">"), let age = Self.age(token.dropFirst()) {
                olderThan = age
            } else if token.hasPrefix("<"), let age = Self.age(token.dropFirst()) {
                newerThan = age
            } else {
                termWords.append(token)
            }
        }
        terms = termWords.joined(separator: " ")
    }

    private static func value(_ token: String, prefix: String) -> String? {
        guard token.hasPrefix(prefix) else { return nil }
        let v = String(token.dropFirst(prefix.count))
        return v.isEmpty ? nil : v
    }

    private static func kind(_ value: String) -> Clip.Kind? {
        switch value.lowercased() {
        case "text": return .text
        case "richtext", "rich": return .richtext
        case "code": return .code
        case "url", "link": return .url
        case "colour", "color": return .colour
        case "image", "img": return .image
        case "file": return .file
        default: return nil
        }
    }

    /// "7d", "2h", "30m" → seconds. Unknown units return nil.
    private static func age(_ text: Substring) -> TimeInterval? {
        guard let unit = text.last, let number = Double(text.dropLast()) else { return nil }
        switch unit {
        case "d": return number * 86_400
        case "h": return number * 3_600
        case "m": return number * 60
        default: return nil
        }
    }
}
