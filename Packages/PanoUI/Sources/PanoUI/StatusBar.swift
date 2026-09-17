import SwiftUI

/// The bottom strip: `12,481 items · 42.6 MB · local`. It restates the privacy claim at every
/// glance and costs nothing (docs/05-design.md). Counts are passed in; the byte figure is a later
/// refinement (needs a size sum from the store).
struct StatusBar: View {
    let itemCount: Int
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack {
            Text("\(itemCount.formatted()) items · local")
                .font(Theme.chipFont)
                .foregroundStyle(Theme.secondary(scheme))
            Spacer()
        }
        .padding(.horizontal, 12)
        .frame(height: Theme.statusHeight)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
    }
}
