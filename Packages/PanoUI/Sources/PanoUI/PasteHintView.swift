import SwiftUI

/// The card shown after ⏎: the clip is on the clipboard, press ⌘V. Without it the panel just
/// disappears and nothing happens where the user is looking, which reads as a broken app rather
/// than as "now press ⌘V". Pano does not paste into other apps (docs/adr/0008), so this is the
/// whole interaction for someone who has not learned it yet.
///
/// Lives in a non-activating panel (`PasteHintController`): the user is about to press ⌘V in their
/// own app, so this must never take key focus.
public struct PasteHintView: View {
    private let onDismiss: () -> Void

    @Environment(\.colorScheme) private var scheme

    public static let width: CGFloat = 400

    public init(onDismiss: @escaping () -> Void) {
        self.onDismiss = onDismiss
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("⌘V")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .frame(width: 38, height: 30)
                .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(.quaternary))
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(.tertiary, lineWidth: 1))

            VStack(alignment: .leading, spacing: 5) {
                Text("Copied. Press ⌘V to paste it.")
                    .font(.system(size: 13, weight: .semibold))
                    .fixedSize(horizontal: false, vertical: true)
                Button("Don't remind me", action: onDismiss)
                    .buttonStyle(.link)
                    .foregroundStyle(.secondary)
                    .font(.system(size: 12))
                    .pointer()
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(width: Self.width, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.separator, lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(scheme == .dark ? 0.5 : 0.18), radius: 18, y: 8)
        .padding(20)  // room for the shadow inside the borderless window
    }
}
