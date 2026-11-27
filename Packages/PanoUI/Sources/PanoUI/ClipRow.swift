import AppKit
import PanoStore
import PanoTransforms
import SwiftUI

struct ClipRow: View {
    let item: ClipListItem
    let model: PanelModel
    let isSelected: Bool
    var quickRank: Int? = nil
    var showLanguage = true
    @Environment(\.colorScheme) private var scheme
    @State private var hovered = false
    @State private var thumbnail: NSImage?

    var body: some View {
        HStack(spacing: 8) {
            kindBadge
                .frame(width: Theme.dotSize, height: Theme.dotSize)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
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
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.brandAccent)
                    .accessibilityLabel("pinned")
            }
            if let quickRank {
                Text("⌘\(quickRank)")
                    .font(Theme.rowMeta)
                    .foregroundStyle(Theme.accent)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(RoundedRectangle(cornerRadius: 4).fill(Theme.accent.opacity(0.12)))
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: Theme.rowCorner)
                .fill(rowFill)
        )
        .contentShape(Rectangle())
        .onHover { hovered = $0 }
        .task(id: item.id) {
            guard item.kind == .image else { return }
            if let cached = PreviewCache.shared.thumbnail(for: item.id) {
                thumbnail = cached
                return
            }
            thumbnail = await model.thumbnail(for: item.id)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    private var rowFill: Color {
        if isSelected {
            return Theme.accent.opacity(scheme == .dark ? 0.28 : 0.14)
        }
        if hovered {
            return Color.primary.opacity(scheme == .dark ? 0.06 : 0.04)
        }
        return .clear
    }

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
        if showLanguage, item.kind == .code, let language = PreviewCache.shared.language(for: item) {
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

    @ViewBuilder private var kindBadge: some View {
        if item.kind == .image, let thumb = PreviewCache.shared.thumbnail(for: item.id) ?? thumbnail {
            Image(nsImage: thumb)
                .resizable()
                .scaledToFill()
                .frame(width: Theme.dotSize, height: Theme.dotSize)
                .clipShape(RoundedRectangle(cornerRadius: 5))
                .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(.separator, lineWidth: 0.5))
        } else if item.kind == .colour, let swatch = PreviewCache.shared.swatchColor(for: item) {
            RoundedRectangle(cornerRadius: 5)
                .fill(swatch)
                .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(.separator, lineWidth: 0.5))
        } else {
            let (symbol, tint) = kindStyle
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: Theme.dotSize, height: Theme.dotSize)
                .background(RoundedRectangle(cornerRadius: 5).fill(tint.opacity(0.14)))
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
