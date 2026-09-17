import Foundation

/// Turns a title or phrase into a URL slug: ASCII-folded, lowercased, non-alphanumeric runs become
/// single hyphens. Offered for a single short line that is not already a slug.
public struct SlugTransform: Transform {
    public let id = "slug"
    public let title = "Slug"
    public init() {}

    public func applies(to text: String) -> Bool {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (1...200).contains(t.count), !t.contains(where: \.isNewline) else { return false }
        guard t.contains(where: \.isLetter) else { return false }
        return t != slugify(t)  // hide the chip when it is already a slug
    }

    public func apply(_ input: String) throws -> TransformOutput {
        TransformOutput(slugify(input))
    }

    private static let turkish: [Character: Character] = [
        "ı": "i", "İ": "i", "ş": "s", "Ş": "s", "ğ": "g", "Ğ": "g",
        "ç": "c", "Ç": "c", "ö": "o", "Ö": "o", "ü": "u", "Ü": "u",
    ]

    private func slugify(_ text: String) -> String {
        // Map Turkish letters that diacritic folding does not reduce (ı has no combining mark),
        // then fold the rest to ASCII.
        let mapped = String(text.map { Self.turkish[$0] ?? $0 })
        let folded = mapped.folding(
            options: [.diacriticInsensitive, .caseInsensitive], locale: .init(identifier: "en_US"))
        var result = ""
        var lastWasDash = false
        for scalar in folded.unicodeScalars {
            let c = Character(scalar)
            if c.isLetter || c.isNumber {
                result.append(Character(c.lowercased()))
                lastWasDash = false
            } else if !lastWasDash {
                result.append("-")
                lastWasDash = true
            }
        }
        return result.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }
}
