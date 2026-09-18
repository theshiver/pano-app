import SwiftUI

/// The bottom strip: `12,481 items · 42.6 MB`, or `18 of 12,481 items` while a search, app or
/// pinboard filter narrows the list (docs/05-design.md). Storage on the right.
struct StatusBar: View {
    let shown: Int
    let total: Int
    let bytes: Int64
    let filtered: Bool
    let openSettings: () -> Void
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack {
            Text(filtered ? "\(shown.formatted()) of \(total.formatted()) items" : "\(total.formatted()) items")
            Spacer()
            Text(ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file))
            Button(action: openSettings) {
                Image(systemName: "gearshape")
                    .font(.system(size: 11))
                    .frame(width: 18, height: 18)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .focusable(false)
            .pointer()
            .help("Settings")
            .accessibilityLabel("Settings")
        }
        .font(Theme.chipFont)
        .foregroundStyle(Theme.secondary(scheme))
        .padding(.horizontal, 12)
        .frame(height: Theme.statusHeight)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .contentShape(Rectangle())
        .gesture(WindowDragGesture())  // borderless panel: the strip is a drag handle
        .accessibilityElement(children: .combine)
    }
}
