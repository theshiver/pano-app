import SwiftUI

struct StatusBar: View {
    let shown: Int
    let total: Int
    let bytes: Int64
    let filtered: Bool
    let openSettings: () -> Void
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                Text(filtered ? "\(shown.formatted()) of \(total.formatted()) items" : "\(total.formatted()) items")
                Spacer()
                Text(ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file))
            }
            .accessibilityElement(children: .combine)

            Button(action: openSettings) {
                Image(systemName: "gearshape")
                    .font(.system(size: 11))
                    .frame(width: 18, height: 18)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .focusable(false)
            .pointer()
            .help("Settings (⌘,)")
            .accessibilityLabel("Settings")
        }
        .font(Theme.chipFont)
        .foregroundStyle(Theme.secondary(scheme))
        .padding(.horizontal, 12)
        .frame(height: Theme.statusHeight)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .contentShape(Rectangle())
        .gesture(WindowDragGesture())
    }
}
