import AppKit
import PanoStore
import SwiftUI

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
                        Image(nsImage: PreviewCache.shared.appIcon(for: app.bundleId))
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
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(isSelected ? Theme.accent : .clear, lineWidth: 1.75)
                )
                .opacity(isSelected || selectedAppId == nil ? 1 : 0.72)
        }
        .buttonStyle(.plain)
        .focusable(false)
        .pointer()
        .help(label)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
