import AppKit
import PanoCore
import SwiftUI

/// The preferences window. Binds to `Preferences` (persisted in UserDefaults); the side-effectful
/// changes — retention applied to the store, launch-at-login registration — are handled by the app
/// through the injected closures so PanoUI stays free of the store and ServiceManagement.
public struct SettingsView: View {
    @Bindable private var prefs: Preferences
    /// Whether macOS currently allows the ⌘V keystroke. Re-read when Pano is activated, which is
    /// exactly when the user comes back from flipping the switch in System Settings; polling would
    /// buy nothing.
    @State private var trusted = false
    private let exclusion: ExclusionModel
    private let onRetentionChanged: () -> Void
    private let onLaunchAtLoginChanged: (Bool) -> Void
    private let onMenuBarIconChanged: (Bool) -> Void
    private let onHotKeyChanged: () -> Void
    private let onOCRChanged: (Bool) -> Void
    private let onMaskSecretsChanged: (Bool) -> Void
    private let onHighlightChanged: (Bool) -> Void
    private let onThemeChanged: (String) -> Void

    public init(
        prefs: Preferences,
        exclusion: ExclusionModel,
        onRetentionChanged: @escaping () -> Void,
        onLaunchAtLoginChanged: @escaping (Bool) -> Void,
        onMenuBarIconChanged: @escaping (Bool) -> Void,
        onHotKeyChanged: @escaping () -> Void,
        onOCRChanged: @escaping (Bool) -> Void,
        onMaskSecretsChanged: @escaping (Bool) -> Void,
        onHighlightChanged: @escaping (Bool) -> Void,
        onThemeChanged: @escaping (String) -> Void
    ) {
        self.prefs = prefs
        self.exclusion = exclusion
        self.onRetentionChanged = onRetentionChanged
        self.onLaunchAtLoginChanged = onLaunchAtLoginChanged
        self.onMenuBarIconChanged = onMenuBarIconChanged
        self.onHotKeyChanged = onHotKeyChanged
        self.onOCRChanged = onOCRChanged
        self.onMaskSecretsChanged = onMaskSecretsChanged
        self.onHighlightChanged = onHighlightChanged
        self.onThemeChanged = onThemeChanged
    }

    public var body: some View {
        TabView {
            general.tabItem { Label("General", systemImage: "gearshape") }
            history.tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
            privacy.tabItem { Label("Privacy", systemImage: "hand.raised") }
            about.tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 460, height: 400)
        .onAppear { trusted = PasteService.isAccessibilityTrusted }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            trusted = PasteService.isAccessibilityTrusted
        }
    }

    // MARK: General — how the panel opens and what it shows

    private var general: some View {
        Form {
            Section("Panel") {
                LabeledContent("Open with") {
                    HotKeyRecorderField(display: prefs.hotKeyDisplay) { code, modifiers, display in
                        prefs.hotKeyCode = code
                        prefs.hotKeyModifiers = modifiers
                        prefs.hotKeyDisplay = display
                        onHotKeyChanged()
                    }
                    .frame(width: 120, height: 22)
                }
                Picker("Appears", selection: $prefs.panelPosition) {
                    Text("Near the cursor").tag(PanelPosition.nearCursor)
                    Text("Centred on the active screen").tag(PanelPosition.activeScreenCentre)
                }
                autoPaste
                Toggle("Launch Pano at login", isOn: toggle(\.launchAtLogin, onLaunchAtLoginChanged))
                Toggle("Show icon in the menu bar", isOn: toggle(\.showMenuBarIcon, onMenuBarIconChanged))
                if !prefs.showMenuBarIcon {
                    note("Settings stay reachable from the ⚙︎ in the panel's status bar; quit with ⌘Q from this window.")
                }
            }
            Section("Content") {
                Toggle("Highlight code", isOn: toggle(\.highlightCode, onHighlightChanged))
                if prefs.highlightCode {
                    Picker(
                        "Theme",
                        selection: Binding(
                            get: { prefs.syntaxTheme },
                            set: {
                                prefs.syntaxTheme = $0
                                onThemeChanged($0)
                            })
                    ) {
                        ForEach(Preferences.syntaxThemes, id: \.id) { theme in
                            Text(theme.label).tag(theme.id)
                        }
                    }
                }
                Toggle("Render Markdown", isOn: $prefs.renderMarkdown)
                note("Markdown clips open formatted; ⇧⏎ still pastes the raw text.")
                Toggle("Read text in images", isOn: toggle(\.ocrEnabled, onOCRChanged))
                note("Makes screenshots searchable. Uses macOS Vision on your Mac; nothing leaves it.")
            }
        }
        .formStyle(.grouped)
    }

    // MARK: History — one question: how long to keep things

    private static let keepOptions: [(days: Int, label: String)] = [
        (1, "1 day"), (7, "1 week"), (30, "1 month"), (90, "3 months"), (365, "1 year"),
    ]

    private var history: some View {
        Form {
            Section {
                Picker(
                    "Keep items for",
                    selection: Binding(
                        get: { prefs.retentionOtherDays },
                        set: {
                            prefs.retentionOtherDays = $0
                            prefs.retentionImageDays = $0
                            onRetentionChanged()
                        })
                ) {
                    ForEach(Self.keepOptions, id: \.days) { option in
                        Text(option.label).tag(option.days)
                    }
                    if !Self.keepOptions.contains(where: { $0.days == prefs.retentionOtherDays }) {
                        Text("\(prefs.retentionOtherDays) days").tag(prefs.retentionOtherDays)
                    }
                }
                note("Older items are removed automatically. Pinned items and anything on a pinboard are kept forever.")
            }
        }
        .formStyle(.grouped)
    }

    // MARK: Privacy — what never gets recorded

    private var privacy: some View {
        Form {
            Section("Secrets") {
                Toggle("Hide things that look like secrets", isOn: toggle(\.maskSecrets, onMaskSecretsChanged))
                note(
                    "API keys, tokens, card and IBAN numbers are shown as •••• and removed after "
                        + "\(prefs.retentionSecretHours) hour\(prefs.retentionSecretHours == 1 ? "" : "s"). "
                        + "Detection is rule-based and runs on your Mac.")
            }
            Section("Excluded apps") {
                if exclusion.apps.isEmpty {
                    note("Nothing copied from an excluded app is ever recorded. Add your password manager here.")
                } else {
                    ForEach(exclusion.apps) { app in
                        HStack {
                            Text(app.displayName)
                            Spacer()
                            Button(role: .destructive) {
                                exclusion.remove(app.bundleId)
                            } label: {
                                Image(systemName: "minus.circle")
                            }
                            .buttonStyle(.borderless)
                            .pointer()
                            .accessibilityLabel("Remove \(app.displayName)")
                        }
                    }
                }
                Button("Add App…") { exclusion.add() }.pointer()
            }
        }
        .formStyle(.grouped)
    }

    // MARK: About

    private var about: some View {
        Form {
            Section {
                HStack(spacing: 12) {
                    Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 64, height: 64)
                    VStack(alignment: .leading) {
                        Text("Pano").font(.title2.bold())
                        Text("Clipboard manager for macOS").foregroundStyle(.secondary)
                    }
                }
                LabeledContent("Version", value: Preferences.marketingVersion)
                LabeledContent("Developer", value: "Can Çetin")
                // Licence and Source are hidden while the repository is private: linking people to
                // a 404 is worse than saying nothing. Put both back when it is opened.
                LabeledContent("Website") {
                    Link("pano-app.com", destination: Self.websiteURL).pointer()
                }
            }
            Section {
                note("Everything stays on this Mac. No account, no sync, no analytics, no network access at all.")
            }
        }
        .formStyle(.grouped)
    }

    private static let websiteURL = URL(string: "https://pano-app.com") ?? URL(fileURLWithPath: "/")

    // MARK: Paste automatically

    /// Off by default, and the only place in the app that asks macOS for permission to send the ⌘V
    /// keystroke — turning this on is what raises the prompt (docs/adr/0003). Left off, ⏎ only puts
    /// the clip on the clipboard, which is the whole app minus one keystroke.
    @ViewBuilder private var autoPaste: some View {
        Toggle(
            "Paste automatically",
            isOn: Binding(
                get: { prefs.autoPaste },
                set: { on in
                    prefs.autoPaste = on
                    // The prompt only appears when the app actually posts an event, so asking is
                    // posting one. Nothing else in Pano calls this.
                    if on && !trusted { PasteService.triggerAccessibilityPrompt() }
                    trusted = PasteService.isAccessibilityTrusted
                }))
        if prefs.autoPaste && !trusted {
            note(
                "macOS has not allowed the keystroke yet. Turn Pano on in System Settings, under "
                    + "Privacy & Security. Until then ⏎ copies and you press ⌘V yourself."
            )
            Button("Open System Settings") { PasteService.openSettingsPane() }
                .pointer()
                .accessibilityLabel("Open System Settings to allow Pano to send the paste keystroke")
        } else if !prefs.autoPaste {
            note("⏎ copies the clip; you press ⌘V. Turn this on and Pano sends the ⌘V for you.")
        }
    }

    // MARK: Helpers

    private func note(_ text: String) -> some View {
        Text(text).font(.system(size: 11)).foregroundStyle(.secondary)
    }

    /// A toggle bound to a preference that also notifies the app of the change.
    private func toggle(_ keyPath: ReferenceWritableKeyPath<Preferences, Bool>, _ changed: @escaping (Bool) -> Void)
        -> Binding<Bool>
    {
        Binding(
            get: { prefs[keyPath: keyPath] },
            set: {
                prefs[keyPath: keyPath] = $0
                changed($0)
            })
    }
}
