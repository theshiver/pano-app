import SwiftUI

/// Live permission state for the first-run window. The controller flips `isTrusted` when the user
/// turns Pano on in System Settings; the view animates the change instead of being rebuilt.
@MainActor
public final class OnboardingState: ObservableObject {
    @Published public var isTrusted: Bool
    public init(isTrusted: Bool) { self.isTrusted = isTrusted }
}

/// First-run screen (design/onboarding-mockup.html). Three parts: the icon and a one-line promise,
/// a looping mini demo that teaches ⌘⇧V → pick → ⏎ without a manual, and the two permissions
/// macOS will ask for. Accessibility is the only one the user has to go and grant, so it gets the
/// button; auto-paste stays optional (docs/adr/0003) and "Skip" leaves the app fully usable.
public struct OnboardingView: View {
    @ObservedObject private var state: OnboardingState
    private let onEnable: () -> Void
    private let onOpenSettings: () -> Void
    private let onSkip: () -> Void

    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var entered = false
    @State private var demo = DemoPhase.idle

    public static let width: CGFloat = 480

    public init(
        state: OnboardingState,
        onEnable: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void,
        onSkip: @escaping () -> Void
    ) {
        self.state = state
        self.onEnable = onEnable
        self.onOpenSettings = onOpenSettings
        self.onSkip = onSkip
    }

    public var body: some View {
        VStack(spacing: 0) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 88, height: 88)
                .shadow(color: Palette.deep.opacity(0.35), radius: 14, y: 10)
                .opacity(entered ? 1 : 0)
                .scaleEffect(entered ? 1 : 0.92)
                .offset(y: entered ? 0 : -18)

            Text("Welcome to Pano")
                .font(.system(size: 24, weight: .bold))
                .tracking(-0.4)
                .padding(.top, 16)
                .padding(.bottom, 4)
                .rise(entered, delay: 0.1)
            Text("Your clipboard, with a memory.")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .rise(entered, delay: 0.16)

            demoStage
                .padding(.top, 22)
                .rise(entered, delay: 0.24)
            caption
                .padding(.top, 10)
                .rise(entered, delay: 0.24)

            permissions
                .padding(.top, 16)
                .rise(entered, delay: 0.32)

            if state.isTrusted {
                Button(action: onSkip) {
                    HStack(spacing: 8) {
                        Text("Start using Pano")
                        Text("⌘⇧V").opacity(0.8)
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .buttonStyle(TealButtonStyle(corner: 9))
                .keyboardShortcut(.defaultAction)
                .padding(.top, 14)
                .transition(.scale(scale: 0.96).combined(with: .opacity))
            }

            footer
                .padding(.top, 14)
                .rise(entered, delay: 0.4)
        }
        .padding(EdgeInsets(top: 44, leading: 32, bottom: 24, trailing: 32))
        .frame(width: Self.width)
        .background(backdrop)
        .animation(.spring(duration: 0.45), value: state.isTrusted)
        .onAppear {
            withAnimation(.spring(duration: 0.7, bounce: 0.3)) { entered = true }
        }
        .task { await runDemo() }
    }

    // MARK: Backdrop: base colour with the brand glow behind the icon and two faint corner washes.

    private var backdrop: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
            RadialGradient(
                colors: [Palette.bright.opacity(scheme == .dark ? 0.22 : 0.28), .clear],
                center: UnitPoint(x: 0.5, y: -0.05), startRadius: 0, endRadius: 340)
            RadialGradient(
                colors: [Palette.pin.opacity(0.10), .clear],
                center: UnitPoint(x: 0.12, y: 1), startRadius: 0, endRadius: 220)
            RadialGradient(
                colors: [Palette.bright.opacity(0.12), .clear],
                center: UnitPoint(x: 0.92, y: 0.92), startRadius: 0, endRadius: 260)
        }
    }

    // MARK: Demo loop

    private enum DemoPhase: Equatable { case idle, keys, panel, picked, returned, pasted }

    private var demoStage: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Palette.card(scheme), Palette.card(scheme).mix(with: Palette.bright, by: 0.12)],
                        startPoint: .top, endPoint: .bottom)
                )
                .shadow(color: .black.opacity(scheme == .dark ? 0.5 : 0.12), radius: 16, y: 8)

            HStack(spacing: 6) {
                keycap("⌘", pressed: demo == .keys)
                keycap("⇧", pressed: demo == .keys)
                keycap("V", pressed: demo == .keys)
                keycap("⏎", pressed: demo == .returned)
                    .opacity(demo == .picked || demo == .returned ? 1 : 0.35)
                    .padding(.leading, 14)
            }
            .padding(.top, 18)

            miniPanel
                .padding(.top, 54)
                .opacity(demo == .panel || demo == .picked || demo == .returned ? 1 : 0)
                .scaleEffect(demo == .panel || demo == .picked || demo == .returned ? 1 : 0.96)

            HStack(spacing: 2) {
                if demo == .pasted {
                    Text("color: #2A6DF0;")
                        .transition(.move(edge: .leading).combined(with: .opacity))
                }
                Rectangle().fill(Palette.accent(scheme)).frame(width: 1.5, height: 14)
                Spacer()
            }
            .font(.system(size: 12, design: .monospaced))
            .clipped()
            .padding(.horizontal, 24)
            .padding(.top, 118)
        }
        .frame(height: 150)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityHidden(true)  // decorative; the caption below says the same in words
    }

    private func keycap(_ label: String, pressed: Bool) -> some View {
        Text(label)
            .font(.system(size: 14, weight: .semibold))
            .frame(minWidth: 30)
            .frame(height: 30)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(pressed ? Palette.row(scheme) : Palette.key(scheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(Palette.keyLine(scheme), lineWidth: 1)
            )
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Palette.keyLine(scheme))
                    .offset(y: pressed ? 1 : 3)
            )
            .offset(y: pressed ? 2 : 0)
    }

    private var miniPanel: some View {
        VStack(spacing: 4) {
            demoRow(icon: Color.green.opacity(0.25), width: 140, selected: false)
            demoRow(icon: Theme.accent, width: 90, selected: demo == .picked || demo == .returned)
            demoRow(icon: Palette.bar(scheme), width: 180, selected: false)
        }
        .padding(6)
        .frame(width: 300)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Palette.panel(scheme))
                .shadow(color: .black.opacity(0.25), radius: 14, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Palette.line(scheme), lineWidth: 0.5))
    }

    private func demoRow(icon: Color, width: CGFloat, selected: Bool) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 4, style: .continuous).fill(icon).frame(width: 14, height: 14)
            Capsule().fill(Palette.bar(scheme)).frame(width: width, height: 8)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 8)
        .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(selected ? Palette.row(scheme) : .clear))
    }

    /// Six-second loop: keys → panel → pick → ⏎ → pasted → idle. Reduce Motion shows one still frame.
    private func runDemo() async {
        if reduceMotion {
            demo = .picked
            return
        }
        let steps: [(DemoPhase, Duration)] = [
            (.keys, .milliseconds(400)), (.panel, .milliseconds(900)), (.picked, .milliseconds(1100)),
            (.returned, .milliseconds(350)), (.pasted, .milliseconds(2200)), (.idle, .milliseconds(1000)),
        ]
        while !Task.isCancelled {
            for (phase, hold) in steps {
                withAnimation(.spring(duration: 0.35)) { demo = phase }
                try? await Task.sleep(for: hold)
                if Task.isCancelled { return }
            }
        }
    }

    private var caption: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                kbd("⌘")
                kbd("⇧")
                kbd("V")
                Text("opens your history anywhere.")
            }
            HStack(spacing: 4) {
                Text("Type, pick,")
                kbd("⏎")
                Text("and it pastes where you were.")
            }
        }
        .font(.system(size: 12.5))
        .foregroundStyle(.secondary)
    }

    private func kbd(_ s: String) -> some View {
        Text(s)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.primary)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(RoundedRectangle(cornerRadius: 4).fill(Palette.key(scheme)))
            .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Palette.keyLine(scheme), lineWidth: 1))
    }

    // MARK: Permissions

    private var permissions: some View {
        VStack(spacing: 0) {
            permissionRow(
                title: "Read the clipboard",
                detail: "macOS asks the first time Pano looks. Just allow it."
            ) {
                Circle().fill(Palette.row(scheme))
                    .overlay(
                        Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundStyle(
                            Palette.accent(scheme)))
            } trailing: {
                EmptyView()
            }
            Divider().padding(.horizontal, 14)
            permissionRow(
                title: "Paste for you",
                detail: state.isTrusted
                    ? "Accessibility is on. Pano can press ⌘V for you."
                    : "Needs Accessibility, so Pano can press ⌘V in the app you were in."
            ) {
                if state.isTrusted {
                    Circle().fill(Color.green)
                        .overlay(
                            Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundStyle(
                                .white)
                        )
                        .transition(.scale(scale: 0.2).combined(with: .opacity))
                } else {
                    PendingDot(color: Palette.accent(scheme), reduceMotion: reduceMotion)
                }
            } trailing: {
                if !state.isTrusted {
                    Button("Enable", action: onEnable)
                        .buttonStyle(TealButtonStyle(corner: 8))
                        .keyboardShortcut(.defaultAction)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Palette.card(scheme))
                .shadow(color: .black.opacity(scheme == .dark ? 0.5 : 0.12), radius: 16, y: 8)
        )
    }

    private func permissionRow<Dot: View, Trailing: View>(
        title: LocalizedStringKey, detail: LocalizedStringKey,
        @ViewBuilder dot: () -> Dot, @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(spacing: 12) {
            dot().frame(width: 22, height: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .semibold))
                Text(detail).font(.system(size: 12)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            trailing()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var footer: some View {
        VStack(spacing: 6) {
            Text("Everything stays on this Mac. No cloud, no account.")
            if !state.isTrusted {
                HStack(spacing: 10) {
                    Button("Skip, I'll press ⌘V myself", action: onSkip)
                        .buttonStyle(.plain)
                        .underline()
                    Text("·")
                    Button("Open System Settings", action: onOpenSettings)
                        .buttonStyle(.plain)
                        .underline()
                }
            }
        }
        .font(.system(size: 12))
        .foregroundStyle(.secondary)
    }
}

/// The dashed circle that marks a permission still waiting; it turns slowly so the row reads as live.
private struct PendingDot: View {
    let color: Color
    let reduceMotion: Bool
    @State private var angle = 0.0

    var body: some View {
        Circle()
            .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
            .foregroundStyle(color.opacity(0.6))
            .rotationEffect(.degrees(angle))
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) { angle = 360 }
            }
    }
}

/// Brand-teal gradient button used only here; the panel keeps the system accent.
private struct TealButtonStyle: ButtonStyle {
    let corner: CGFloat
    @Environment(\.colorScheme) private var scheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Palette.bright, Palette.accent(scheme)], startPoint: .top, endPoint: .bottom)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: corner, style: .continuous).strokeBorder(
                            .white.opacity(0.25), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.25), radius: 1, y: 1)
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

/// Onboarding-only colours, matching design/onboarding-mockup.html. Teal is the icon's colour; the
/// panel itself stays on Theme.accent (blue).
private enum Palette {
    static let bright = Color(red: 0x19 / 255, green: 0xC6 / 255, blue: 0xB0 / 255)
    static let deep = Color(red: 0x0B / 255, green: 0x6E / 255, blue: 0x66 / 255)
    static let pin = Color(red: 0xE5 / 255, green: 0x48 / 255, blue: 0x4D / 255)
    static func accent(_ s: ColorScheme) -> Color {
        s == .dark
            ? Color(red: 0x14 / 255, green: 0xB8 / 255, blue: 0xA6 / 255)
            : Color(red: 0x0F / 255, green: 0x8F / 255, blue: 0x82 / 255)
    }
    static func card(_ s: ColorScheme) -> Color { s == .dark ? Color(white: 0.15) : .white }
    static func panel(_ s: ColorScheme) -> Color { s == .dark ? Color(white: 0.175) : .white }
    static func row(_ s: ColorScheme) -> Color {
        s == .dark
            ? Color(red: 0x16 / 255, green: 0x3C / 255, blue: 0x38 / 255)
            : Color(red: 0xE3 / 255, green: 0xF6 / 255, blue: 0xF3 / 255)
    }
    static func key(_ s: ColorScheme) -> Color { s == .dark ? Color(white: 0.21) : .white }
    static func keyLine(_ s: ColorScheme) -> Color { s == .dark ? Color(white: 0.29) : Color(white: 0.83) }
    static func bar(_ s: ColorScheme) -> Color {
        s == .dark ? Color(white: 0.28) : Color(red: 0xD9 / 255, green: 0xDC / 255, blue: 0xE3 / 255)
    }
    static func line(_ s: ColorScheme) -> Color { s == .dark ? Color(white: 0.21) : Color(white: 0.9) }
}

extension View {
    /// Entrance: fades and rises into place once `on` flips, staggered by `delay`.
    fileprivate func rise(_ on: Bool, delay: Double) -> some View {
        opacity(on ? 1 : 0)
            .offset(y: on ? 0 : 8)
            .animation(.spring(duration: 0.5).delay(delay), value: on)
    }
}
