import AppKit
import SwiftUI

/// Renders RTF/HTML clips and Markdown HTML previews via AppKit's importers while stripping
/// hard-coded colours and normalising extreme font sizes for the preview pane.
public enum RichPreview {
    @MainActor
    public static func prewarm() {
        _ = attributed(html: "<p>a</p>")
        _ = NSAttributedString(rtf: Data("{\\rtf1\\ansi a}".utf8), documentAttributes: nil)
    }

    static func attributed(payload: [(uti: String, data: Data)]) -> AttributedString? {
        if let rtf = payload.first(where: { $0.uti == "public.rtf" })?.data,
            let rendered = NSMutableAttributedString(rtf: rtf, documentAttributes: nil)
        {
            cleanAndNormalize(rendered)
            return AttributedString(rendered)
        }
        if let html = payload.first(where: { $0.uti == "public.html" })?.data,
            let string = String(data: html, encoding: .utf8)
        {
            return attributed(html: string)
        }
        return nil
    }

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
        cleanAndNormalize(rendered)
        return AttributedString(rendered)
    }

    static func cleanAndNormalize(_ rendered: NSMutableAttributedString) {
        let full = NSRange(location: 0, length: rendered.length)
        rendered.removeAttribute(.foregroundColor, range: full)
        rendered.removeAttribute(.backgroundColor, range: full)
        rendered.enumerateAttribute(.font, in: full) { value, range, _ in
            guard let font = value as? NSFont else { return }
            let clamped = min(max(font.pointSize, 12.0), 17.5)
            guard abs(clamped - font.pointSize) > 0.1 else { return }
            if let resized = NSFont(descriptor: font.fontDescriptor, size: clamped) {
                rendered.addAttribute(.font, value: resized, range: range)
            }
        }
    }
}
