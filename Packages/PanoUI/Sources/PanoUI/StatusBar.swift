import SwiftUI

struct StatusBar: View {
    let shown: Int
    let total: Int
    let bytes: Int64
    let filtered: Bool
    let updateVersion: String?
    let openUpdates: () -> Void
    let dismissUpdate: () -> Void
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

            if let updateVersion {
                Button(action: openUpdates) {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 10))
                        Text("v\(updateVersion)")
                    }
                    .foregroundStyle(Theme.accent)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(Theme.accent.opacity(scheme == .dark ? 0.18 : 0.12))
                    )
                }
                .buttonStyle(.plain)
                .focusable(false)
                .pointer()
                .help("Pano v\(updateVersion) is available — click to update")
                .accessibilityLabel("Update available, version \(updateVersion)")
                .contextMenu {
                    Button("Dismiss for v\(updateVersion)", action: dismissUpdate)
                }
            }

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
