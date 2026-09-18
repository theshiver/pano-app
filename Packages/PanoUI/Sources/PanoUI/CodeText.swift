import AppKit
import PanoTransforms
import SwiftUI

/// Builds a syntax-highlighted `AttributedString` from code, using PanoTransforms' dependency-free
/// highlighter. Colours are semantic `NSColor`s so both themes work without a custom palette.
enum CodeText {
    static func highlighted(_ code: String, language: CodeHighlighter.Language) -> AttributedString {
        let attributed = NSMutableAttributedString(
            string: code,
            attributes: [
                .font: NSFont.monospacedSystemFont(ofSize: 10.5, weight: .regular),
                .foregroundColor: NSColor.labelColor,
            ]
        )
        for span in CodeHighlighter.spans(for: code, language: language) {
            attributed.addAttribute(
                .foregroundColor, value: colour(span.kind),
                range: NSRange(location: span.start, length: span.length)
            )
        }
        return AttributedString(attributed)
    }

    private static func colour(_ kind: CodeHighlighter.TokenKind) -> NSColor {
        switch kind {
        case .keyword: return .systemPink
        case .string: return .systemGreen
        case .comment: return .secondaryLabelColor
        case .number: return .systemOrange
        }
    }
}
