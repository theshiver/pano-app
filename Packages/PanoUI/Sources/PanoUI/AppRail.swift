import AppKit
import PanoStore
import SwiftUI

/// The source-app rail (docs/05-design.md): "All" on top, then one icon per app clips came from,
/// most recent first. Tapping filters the list to that app; the selected icon gets a window-coloured
/// ring inside an accent ring. Keyboard: ⌘] / ⌘[ walk the rail, `app:` in the search does the same.
struct AppRail: View {
    let model: PanelModel
    private var apps: [SourceApp] { model.apps }
    private var selectedAppId: String? { model.selectedAppId }
    private func select(_ id: String?) { model.selectApp(id) }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 8) {
                railButton(label: "All apps", isSelected: selectedAppId == nil) {
                    select(nil)
                } icon: {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 14, weight: .medium))
                        .frame(width: 30, height: 30)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                }
                ForEach(apps) { app in
                    railButton(label: app.name ?? app.bundleId, isSelected: selectedAppId == app.id) {
                        select(app.id)
                    } icon: {
                        Image(nsImage: Self.icon(for: app.bundleId))
                            .resizable()
                            .frame(width: 30, height: 30)
                    }
                }
                PinboardRail(model: model)
            }
            .padding(.vertical, 10)
            .frame(width: Theme.railWidth)
        }
    }

    private func railButton<Icon: View>(
        label: String, isSelected: Bool, action: @escaping () -> Void, @ViewBuilder icon: () -> Icon
    ) -> some View {
        Button(action: action) {
            icon()
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(2)
                .background(.background, in: RoundedRectangle(cornerRadius: 10))
                .padding(2)
                .background(isSelected ? Theme.accent : .clear, in: RoundedRectangle(cornerRadius: 12))
                .opacity(isSelected || selectedAppId == nil ? 1 : 0.55)
        }
        .buttonStyle(.plain)
        .focusable(false)  // the search field owns keyboard focus; rail buttons must never take it
        .pointer()
        .help(label)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    // ponytail: NSWorkspace lookup per render; cache in a dictionary if the rail ever feels slow.
    private static func icon(for bundleId: String) -> NSImage {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        return NSWorkspace.shared.icon(for: .applicationBundle)
    }
}
