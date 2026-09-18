import AppKit
import Highlightr
import PanoTransforms
import SwiftUI

/// Syntax-highlights code with Highlightr (highlight.js via JavaScriptCore — ADR 0007). Runs on its
/// own actor so a 3000-line clip never stalls the panel: the preview shows plain text at once and
/// swaps in the highlighted result when it lands. The engine (a JSContext) lives on that actor.
actor CodeText {
    static let shared = CodeText()
    private let highlightr = Highlightr()

    struct Result: Sendable {
        var text: AttributedString
        /// The theme's own background, applied behind the code so a dark theme stays readable on a
        /// light system (and vice versa) instead of clashing with the panel material.
        var background: Color
    }

    /// Only this much of a clip is highlighted and laid out; the preview is a glance, the paste is
    /// whole. Beyond it the preview says how much was cut.
    static let previewLineLimit = 300

    static func preview(_ code: String) -> (text: String, cutLines: Int) {
        let lines = code.split(separator: "\n", omittingEmptySubsequences: false)
        guard lines.count > previewLineLimit else { return (code, 0) }
        return (lines.prefix(previewLineLimit).joined(separator: "\n"), lines.count - previewLineLimit)
    }

    func highlight(_ code: String, language: CodeHighlighter.Language?, theme: String) -> Result? {
        guard let highlightr else { return nil }
        highlightr.setTheme(to: theme)
        highlightr.theme.setCodeFont(.monospacedSystemFont(ofSize: 10.5, weight: .regular))
        guard let attributed = highlightr.highlight(code, as: language.map(Self.hljsName), fastRender: true) else {
            return nil
        }
        return Result(
            text: AttributedString(attributed),
            background: Color(nsColor: highlightr.theme.themeBackgroundColor)
        )
    }

    /// Maps our language guess to highlight.js's language identifiers.
    private static func hljsName(_ language: CodeHighlighter.Language) -> String {
        switch language {
        case .shell: return "bash"
        case .html: return "xml"
        default: return language.rawValue
        }
    }
}
