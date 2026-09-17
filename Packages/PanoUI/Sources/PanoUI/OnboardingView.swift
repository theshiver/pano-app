import SwiftUI

/// First-run screen for the one permission Pano needs: Accessibility, so it can press ⌘V for you
/// (docs/adr/0003). There is no API to grant it inline — every Mac app sends the user to System
/// Settings — so this explains the one switch and watches for it to flip. Auto-paste is optional:
/// "Skip" leaves the app fully usable with a manual ⌘V.
public struct OnboardingView: View {
    /// Triggers the macOS permission prompt (by posting an event) and opens the Settings pane.
    private let onEnable: () -> Void
    private let onOpenSettings: () -> Void
    private let onSkip: () -> Void
    private let isTrusted: Bool

    public init(
        isTrusted: Bool,
        onEnable: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void,
        onSkip: @escaping () -> Void
    ) {
        self.isTrusted = isTrusted
        self.onEnable = onEnable
        self.onOpenSettings = onOpenSettings
        self.onSkip = onSkip
    }

    public var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.on.clipboard.fill")
                .font(.system(size: 44))
                .foregroundStyle(Theme.accent)

            Text("Welcome to Pano")
                .font(.system(size: 22, weight: .semibold))

            Text(
                "Press ⌘⇧V anywhere to open your clipboard history, pick an item, and it pastes "
                    + "into whatever you were doing. Everything stays on this Mac — no cloud, no account."
            )
            .font(.system(size: 13))
            .multilineTextAlignment(.center)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

            if isTrusted {
                Label("Auto-paste is enabled", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.system(size: 13, weight: .medium))
                Button("Start Using Pano", action: onSkip)
                    .keyboardShortcut(.defaultAction)
            } else {
                VStack(spacing: 6) {
                    Text("To paste for you, Pano needs Accessibility access.")
                        .font(.system(size: 12, weight: .medium))
                    Text(
                        "Click Enable, then turn Pano on in System Settings. "
                            + "It is the only permission Pano asks for."
                    )
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 10) {
                    Button("Enable Auto-Paste", action: onEnable)
                        .keyboardShortcut(.defaultAction)
                    Button("Open Settings", action: onOpenSettings)
                }
                Button("Skip — I'll press ⌘V myself", action: onSkip)
                    .buttonStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(32)
        .frame(width: 420)
        .background(.regularMaterial)
    }
}
