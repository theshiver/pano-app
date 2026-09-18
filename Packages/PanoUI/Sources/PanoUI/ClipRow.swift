import PanoStore
import PanoTransforms
import SwiftUI

/// One result row: type dot, single-line content, and a metadata line (source · age · copies).
/// docs/05-design.md row anatomy. Thumbnails, colour swatches and code language come with the
/// kinds that need them in later weeks; this renders the common text/url/file case.
struct ClipRow: View {
    let item: ClipListItem
    let isSelected: Bool
    var quickRank: Int? = nil
    var showLanguage = true
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(spacing: 8) {
            kindBadge
                .frame(width: Theme.dotSize, height: Theme.dotSize)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text(item.isMasked ? "••••••••" : firstLine)
                    .font(Theme.rowContent)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(metadata)
                    .font(Theme.rowMeta)
                    .foregroundStyle(Theme.secondary(scheme))
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            if item.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(Theme.accent)
                    .accessibilityLabel("pinned")
            }
            if let quickRank {
                Text("⌘\(quickRank)")
                    .font(Theme.rowMeta)
                    .foregroundStyle(Theme.accent)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(RoundedRectangle(cornerRadius: 4).fill(Theme.accent.opacity(0.12)))
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: Theme.rowCorner)
                .fill(isSelected ? Theme.accent.opacity(scheme == .dark ? 0.28 : 0.14) : .clear)
        )
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    /// One line is all the row shows, so only that much is handed to layout (a 3000-line clip
    /// would otherwise be measured in full on every render).
    private var firstLine: String {
        guard let content = item.content, !content.isEmpty else { return placeholder }
        return String(content.prefix { $0 != "\n" }.prefix(200))
    }

    private var placeholder: String {
        switch item.kind {
        case .image: return "Image"
        case .file: return "File"
        default: return ""
        }
    }

    private var metadata: String {
        var parts: [String] = []
        if item.isMasked { parts.append("not stored") }
        if showLanguage, item.kind == .code, let content = item.content,
            let language = CodeHighlighter.detectLanguage(String(content.prefix(4000)))
        {
            parts.append(language.rawValue)
        }
        if let source = item.sourceName ?? item.sourceBundleId { parts.append(source) }
        parts.append(Self.age(item.lastSeenAt))
        if item.copyCount > 1 { parts.append("×\(item.copyCount)") }
        return parts.joined(separator: " · ")
    }

    private var accessibilityText: String {
        "\(item.kind.rawValue), \(item.isMasked ? "hidden" : (item.content ?? placeholder)), \(metadata)"
    }

    /// A symbol per kind on a tinted tile, so the type reads at a glance; a colour clip shows the
    /// colour itself.
    @ViewBuilder private var kindBadge: some View {
        if item.kind == .colour, let hex = item.content.flatMap({ try? ColourTransform().apply($0).text }),
            let swatch = Color(hex: hex)
        {
            RoundedRectangle(cornerRadius: 5).fill(swatch)
                .overlay(RoundedRectangle(cornerRadius: 5).stroke(.separator))
        } else {
            let (symbol, tint) = kindStyle
            Image(systemName: symbol)
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: Theme.dotSize, height: Theme.dotSize)
                .background(RoundedRectangle(cornerRadius: 5).fill(tint.opacity(0.15)))
        }
    }

    private var kindStyle: (String, Color) {
        switch item.kind {
        case .url: return ("link", .blue)
        case .image: return ("photo", .purple)
        case .file: return ("doc", .orange)
        case .colour: return ("paintpalette", .pink)
        case .code: return ("chevron.left.forwardslash.chevron.right", .green)
        case .richtext: return ("textformat", .teal)
        case .text: return ("text.alignleft", Theme.secondary(scheme))
        }
    }

    static func age(_ date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        switch seconds {
        case ..<60: return "now"
        case ..<3600: return "\(seconds / 60)m"
        case ..<86400: return "\(seconds / 3600)h"
        default: return "\(seconds / 86400)d"
        }
    }
}
