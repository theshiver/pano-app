import AppKit
import SwiftUI

/// Renders a transform's HTML (Markdown) in the preview via AppKit's HTML importer. The importer's
/// hard-coded text colours are stripped so the result follows the panel's light/dark scheme.
enum RichPreview {
    static func attributed(html: String) -> AttributedString? {
        let styled = "<style>body{font:13px -apple-system;} code{font:12px Menlo;}</style>" + html
        guard
            let rendered = try? NSMutableAttributedString(
                data: Data(styled.utf8),
                options: [
                    .documentType: NSAttributedString.DocumentType.html,
                    .characterEncoding: String.Encoding.utf8.rawValue,
                ],
                documentAttributes: nil)
        else { return nil }
        rendered.removeAttribute(.foregroundColor, range: NSRange(location: 0, length: rendered.length))
        return AttributedString(rendered)
    }
}
