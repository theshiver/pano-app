import PanoStore
import SwiftUI

/// The right-hand preview: a header strip (source · time), the body, and the keyboard-hint footer.
/// Transform chips, colour format lists, syntax highlighting and image+OCR come in weeks 5–6;
/// this shows the text body, which is what most clips are.
struct PreviewPane: View {
    let item: ClipListItem?
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let item {
                header(item)
                Divider()
                ScrollView {
                    Text(item.isMasked ? "Not stored — this looked like a secret." : (item.content ?? "—"))
                        .font(Theme.previewBody)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                }
                Spacer(minLength: 0)
                footer
            } else {
                Spacer()
                Text("No selection")
                    .font(Theme.rowContent)
                    .foregroundStyle(Theme.secondary(scheme))
                    .frame(maxWidth: .infinity)
                Spacer()
            }
        }
    }

    private func header(_ item: ClipListItem) -> some View {
        HStack {
            Text(item.sourceName ?? item.sourceBundleId ?? "Unknown")
                .font(Theme.rowMeta)
                .foregroundStyle(Theme.secondary(scheme))
            Spacer()
            Text(ClipRow.age(item.lastSeenAt))
                .font(Theme.rowMeta)
                .foregroundStyle(Theme.secondary(scheme))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var footer: some View {
        HStack {
            Text("⏎ paste · esc close")
                .font(Theme.chipFont)
                .foregroundStyle(Theme.secondary(scheme))
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}
