import AppKit
import Highlightr
import PanoTransforms
import SwiftUI

/// Syntax-highlights code with Highlightr (highlight.js via JavaScriptCore — ADR 0007). The engine
/// is created once and reused; it is JS-backed, so it stays on the main actor.
@MainActor
enum CodeText {
    private static let highlightr = Highlightr()

    struct Result {
        var text: AttributedString
        /// The theme's own background, applied behind the code so a dark theme stays readable on a
        /// light system (and vice versa) instead of clashing with the panel material.
        var background: Color
    }

    static func highlight(_ code: String, language: CodeHighlighter.Language?, theme: String) -> Result? {
        guard let highlightr else { return nil }
        highlightr.setTheme(to: theme)
        highlightr.theme.setCodeFont(.monospacedSystemFont(ofSize: 10.5, weight: .regular))
        guard let attributed = highlightr.highlight(code, as: language.map(hljsName), fastRender: true) else {
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
