import SwiftUI

/// The empty search field's placeholder: "Search" plus one example filter at a time, each sliding
/// in from below and out through the top every few seconds so people discover the syntax without
/// reading a manual. Reduce Motion swaps without sliding.
struct SearchHints: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var index = 0

    static let hints = ["type:code", "app:xcode", ">7d", "pinned:", "type:image", "<2h"]

    var body: some View {
        HStack(spacing: 0) {
            Text("Search  ")
            Text("try ")
            Text(Self.hints[index])
                .id(index)
                .transition(
                    reduceMotion
                        ? .opacity
                        : .asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .move(edge: .top).combined(with: .opacity)))
        }
        .font(Theme.searchFont)
        .foregroundStyle(Theme.secondary(scheme).opacity(0.7))
        .clipped()
        .allowsHitTesting(false)
        .accessibilityHidden(true)  // the field's own accessibility label covers it
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3))
                withAnimation(.easeInOut(duration: 0.35)) { index = (index + 1) % Self.hints.count }
            }
        }
    }
}
