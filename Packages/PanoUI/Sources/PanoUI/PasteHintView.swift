import SwiftUI

/// The card shown after ⏎ when the clip only reached the clipboard and not the app the user came
/// from. Without it the panel just disappears and nothing happens where the user is looking, which
/// reads as a broken app rather than as "now press ⌘V" — so this says what happened, and offers the
/// setting that would have made ⏎ do the whole job.
///
/// Lives in a non-activating panel (`PasteHintController`): the user is about to press ⌘V in their
/// own app, so this must never take key focus.
public struct PasteHintView: View {
    /// Why ⏎ did not reach the other app. The two cases need different words and different actions:
    /// one is a setting the user has not turned on, the other is a setting they did turn on that
    /// macOS is not honouring yet.
    public enum Reason: Sendable {
        case autoPasteOff
        case permissionMissing
    }

    private let reason: Reason
    private let onEnable: () -> Void
    private let onDismiss: () -> Void

    @Environment(\.colorScheme) private var scheme

    public static let width: CGFloat = 400

    public init(reason: Reason, onEnable: @escaping () -> Void, onDismiss: @escaping () -> Void) {
        self.reason = reason
        self.onEnable = onEnable
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
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    Button(actionLabel, action: onEnable)
                        .buttonStyle(.link)
                        .pointer()
                    Text("·").foregroundStyle(.tertiary)
                    Button("Don't remind me", action: onDismiss)
                        .buttonStyle(.link)
                        .foregroundStyle(.secondary)
                        .pointer()
                }
                .font(.system(size: 12))
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

    private var title: LocalizedStringKey {
        switch reason {
        case .autoPasteOff: "Copied. Press ⌘V to paste it."
        case .permissionMissing: "Copied. Pano can't press ⌘V until you allow it."
        }
    }

    private var actionLabel: LocalizedStringKey {
        switch reason {
        case .autoPasteOff: "Let Pano paste for me"
        case .permissionMissing: "Finish setup"
        }
    }
}
