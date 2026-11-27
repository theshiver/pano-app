import AppKit
import PanoCore
import SwiftUI

public struct SettingsView: View {
    @Bindable private var prefs: Preferences
    private let exclusion: ExclusionModel
    private let navigation: SettingsNavigation
    private let update: UpdateModel?
    private let supportsAutoPaste: Bool
    private let isAccessibilityTrusted: () -> Bool
    private let onOpenAccessibilitySettings: () -> Void
    private let onRevealAppInFinder: () -> Void
    private let onRetentionChanged: () -> Void
    private let onLaunchAtLoginChanged: (Bool) -> Void
    private let onMenuBarIconChanged: (Bool) -> Void
    private let onHotKeyChanged: () -> Void
    private let onOCRChanged: (Bool) -> Void
    private let onMaskSecretsChanged: (Bool) -> Void
    private let onHighlightChanged: (Bool) -> Void
    private let onThemeChanged: (String) -> Void
    private let onClearLastHour: () -> Void
    private let onClearAllHistory: () -> Void
    private let isCapturePaused: () -> Bool
    private let onToggleCapturePaused: (Bool) -> Void

    @State private var hoveredTab: SettingsTab?
    @State private var capturePaused = false
    @State private var accessibilityGranted = false

    public init(
        prefs: Preferences,
        exclusion: ExclusionModel,
        navigation: SettingsNavigation = SettingsNavigation(),
        update: UpdateModel? = nil,
        supportsAutoPaste: Bool = false,
        isAccessibilityTrusted: @escaping () -> Bool = { false },
        onOpenAccessibilitySettings: @escaping () -> Void = {},
        onRevealAppInFinder: @escaping () -> Void = {},
        onRetentionChanged: @escaping () -> Void,
        onLaunchAtLoginChanged: @escaping (Bool) -> Void,
        onMenuBarIconChanged: @escaping (Bool) -> Void,
        onHotKeyChanged: @escaping () -> Void,
        onOCRChanged: @escaping (Bool) -> Void,
        onMaskSecretsChanged: @escaping (Bool) -> Void,
        onHighlightChanged: @escaping (Bool) -> Void,
        onThemeChanged: @escaping (String) -> Void,
        onClearLastHour: @escaping () -> Void = {},
        onClearAllHistory: @escaping () -> Void = {},
        isCapturePaused: @escaping () -> Bool = { false },
        onToggleCapturePaused: @escaping (Bool) -> Void = { _ in }
    ) {
        self.prefs = prefs
        self.exclusion = exclusion
        self.navigation = navigation
        self.update = update
        self.supportsAutoPaste = supportsAutoPaste
        self.isAccessibilityTrusted = isAccessibilityTrusted
        self.onOpenAccessibilitySettings = onOpenAccessibilitySettings
        self.onRevealAppInFinder = onRevealAppInFinder
        self.onRetentionChanged = onRetentionChanged
        self.onLaunchAtLoginChanged = onLaunchAtLoginChanged
        self.onMenuBarIconChanged = onMenuBarIconChanged
        self.onHotKeyChanged = onHotKeyChanged
        self.onOCRChanged = onOCRChanged
        self.onMaskSecretsChanged = onMaskSecretsChanged
        self.onHighlightChanged = onHighlightChanged
        self.onThemeChanged = onThemeChanged
        self.onClearLastHour = onClearLastHour
        self.onClearAllHistory = onClearAllHistory
        self.isCapturePaused = isCapturePaused
        self.onToggleCapturePaused = onToggleCapturePaused
    }

    public var body: some View {
        VStack(spacing: 0) {
            tabBar
            Divider()
            Group {
                switch navigation.selectedTab {
                case .general: general
                case .history: history
                case .privacy: privacy
                case .about: about
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 480, height: supportsAutoPaste ? 540 : 470)
        .onAppear {
            capturePaused = isCapturePaused()
            accessibilityGranted = isAccessibilityTrusted()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            accessibilityGranted = isAccessibilityTrusted()
        }
    }

    private var tabBar: some View {
        HStack(spacing: 6) {
            ForEach(SettingsTab.allCases) { tab in
                let active = navigation.selectedTab == tab
                let hovered = hoveredTab == tab
                Button {
                    navigation.selectedTab = tab
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: tab.symbol)
                            .font(.system(size: 16, weight: active ? .semibold : .regular))
                            .foregroundStyle(active ? Theme.accent : Color.primary.opacity(0.68))
                            .overlay(alignment: .topTrailing) {
                                if tab == .about, update?.availableRelease != nil {
                                    Circle()
                                        .fill(Theme.accent)
                                        .frame(width: 6, height: 6)
                                        .offset(x: 4, y: -2)
                                }
                            }
                        Text(tab.label)
                            .font(.system(size: 11, weight: active ? .semibold : .medium))
                            .foregroundStyle(active ? Color.primary : Color.primary.opacity(0.68))
                    }
                    .frame(width: 78)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(
                                active
                                    ? Theme.accent.opacity(0.14)
                                    : (hovered ? Color.primary.opacity(0.06) : .clear)
                            )
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .focusable(false)
                .focusEffectDisabled()
                .onHover { hoveredTab = $0 ? tab : (hoveredTab == tab ? nil : hoveredTab) }
                .pointer()
                .accessibilityAddTraits(active ? [.isSelected] : [])
            }
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: General

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
                    .frame(width: 130, height: 22)
                }
                Picker("Appears", selection: $prefs.panelPosition) {
                    Text("Near the cursor").tag(PanelPosition.nearCursor)
                    Text("Centred on the active screen").tag(PanelPosition.activeScreenCentre)
                }
                Toggle("Launch Pano at login", isOn: toggle(\.launchAtLogin, onLaunchAtLoginChanged))
                Toggle("Show icon in the menu bar", isOn: toggle(\.showMenuBarIcon, onMenuBarIconChanged))
                if !prefs.showMenuBarIcon {
                    note("Settings stay reachable from ⚙︎ in the panel's status bar; quit with ⌘Q from this window.")
                }
                Toggle(
                    "Pause clipboard capture",
                    isOn: Binding(
                        get: { capturePaused },
                        set: {
                            capturePaused = $0
                            onToggleCapturePaused($0)
                        }
                    )
                )
            }

            if supportsAutoPaste {
                Section("Pasting") {
                    Toggle("Paste automatically on Return", isOn: $prefs.autoPaste)
                    if prefs.autoPaste {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(accessibilityGranted ? Color.green : Color.orange)
                                .frame(width: 8, height: 8)
                            Text(
                                accessibilityGranted
                                    ? "Accessibility permission granted"
                                    : "Accessibility permission needed in System Settings"
                            )
                            .font(.system(size: 11.5))
                            .foregroundStyle(.secondary)
                            Spacer()
                            Link("Setup guide (macOS 15–27)", destination: Self.autoPasteGuideURL)
                                .font(.system(size: 11.5))
                                .pointer()
                        }
                        if !accessibilityGranted {
                            HStack(spacing: 8) {
                                Button("Open System Settings…", action: onOpenAccessibilitySettings).pointer()
                                Button("Show Pano in Finder", action: onRevealAppInFinder).pointer()
                            }
                            note(
                                "Add Pano under Privacy & Security → Accessibility (and confirm any device control prompt on macOS 27.3+) so Return sends ⌘V directly."
                            )
                        }
                    }
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
                note("Markdown clips open formatted; ⇧⏎ still copies the raw text.")
                Toggle("Read text in images", isOn: toggle(\.ocrEnabled, onOCRChanged))
                note("Makes screenshots searchable. Uses macOS Vision on your Mac; nothing leaves it.")
            }
        }
        .formStyle(.grouped)
    }

    // MARK: History

    private static let keepOptions: [(days: Int, label: String)] = [
        (1, "1 day"), (7, "1 week"), (30, "1 month"), (90, "3 months"), (365, "1 year"),
    ]

    private var history: some View {
        Form {
            Section("Retention") {
                Picker(
                    "Keep text & links for",
                    selection: Binding(
                        get: { prefs.retentionOtherDays },
                        set: {
                            prefs.retentionOtherDays = $0
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
                Picker(
                    "Keep images for",
                    selection: Binding(
                        get: { prefs.retentionImageDays },
                        set: {
                            prefs.retentionImageDays = $0
                            onRetentionChanged()
                        })
                ) {
                    ForEach(Self.keepOptions, id: \.days) { option in
                        Text(option.label).tag(option.days)
                    }
                    if !Self.keepOptions.contains(where: { $0.days == prefs.retentionImageDays }) {
                        Text("\(prefs.retentionImageDays) days").tag(prefs.retentionImageDays)
                    }
                }
                note("Older items are swept automatically. Pinned items and anything on a pinboard are kept forever.")
            }

            Section("Cleanup") {
                HStack(spacing: 10) {
                    Button("Clear Last Hour", action: onClearLastHour).pointer()
                    Button("Clear All Unpinned…", role: .destructive, action: onClearAllHistory).pointer()
                }
                Button("Reset inline tips & copy hint") {
                    prefs.copyHintDismissed = false
                    prefs.ocrTipDismissed = false
                    prefs.transformTipDismissed = false
                }
                .pointer()
            }
        }
        .formStyle(.grouped)
    }

    // MARK: Privacy

    private static let secretHourOptions = [1, 4, 12, 24]

    private var privacy: some View {
        Form {
            Section("Secrets") {
                Toggle("Hide things that look like secrets", isOn: toggle(\.maskSecrets, onMaskSecretsChanged))
                Picker(
                    "Delete detected secrets after",
                    selection: Binding(
                        get: { prefs.retentionSecretHours },
                        set: {
                            prefs.retentionSecretHours = $0
                            onRetentionChanged()
                        })
                ) {
                    ForEach(Self.secretHourOptions, id: \.self) { hours in
                        Text("\(hours) hour\(hours == 1 ? "" : "s")").tag(hours)
                    }
                    if !Self.secretHourOptions.contains(prefs.retentionSecretHours) {
                        Text("\(prefs.retentionSecretHours) hours").tag(prefs.retentionSecretHours)
                    }
                }
                note(
                    "API keys, tokens, card and IBAN numbers are masked in the list. Rule-based and strictly on-device."
                )
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
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Pano").font(.title2.bold())
                        Text("Open-source clipboard manager for macOS").foregroundStyle(.secondary)
                    }
                }
                LabeledContent("Version", value: Preferences.marketingVersion)
                LabeledContent(
                    "Distribution", value: supportsAutoPaste ? "Direct (Auto-Paste enabled)" : "Mac App Store")
                LabeledContent("Developer", value: "Can Çetin")
                LabeledContent("Licence", value: "MIT (Open Source)")
                LabeledContent("Source") {
                    Link("github.com/theshiver/pano-app", destination: Self.githubURL).pointer()
                }
                LabeledContent("Website") {
                    Link("pano-app.com", destination: Self.websiteURL).pointer()
                }
            }
            if let update {
                updatesSection(update)
            }
            Section {
                if update != nil {
                    note(
                        "Your clipboard data never leaves this Mac. No account, no sync, no telemetry. Only optional update checks contact GitHub."
                    )
                } else {
                    note("Everything stays on this Mac. No account, no sync, no telemetry, no network access at all.")
                }
            }
        }
        .formStyle(.grouped)
    }

    @ViewBuilder
    private func updatesSection(_ update: UpdateModel) -> some View {
        Section("Updates") {
            switch update.status {
            case .idle:
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Current version: \(Preferences.marketingVersion)")
                        if let checkedAt = update.lastCheckedAt {
                            note("Last checked \(checkedAt.formatted(date: .abbreviated, time: .shortened))")
                        }
                    }
                    Spacer()
                    Button("Check for Updates") { update.checkNow() }
                        .pointer()
                }
            case .checking:
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Checking for updates…")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Check for Updates") {}
                        .disabled(true)
                }
            case .upToDate(let checkedAt):
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Pano \(Preferences.marketingVersion) is up to date")
                        note("Last checked \(checkedAt.formatted(date: .abbreviated, time: .shortened))")
                    }
                    Spacer()
                    Button("Check for Updates") { update.checkNow() }
                        .pointer()
                }
            case .available(let release):
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.circle.fill")
                            .foregroundStyle(Theme.accent)
                        Text("Pano \(release.version) is available")
                            .fontWeight(.semibold)
                    }
                    if !release.notes.isEmpty {
                        Text(release.notes)
                            .font(.system(size: 11.5))
                            .foregroundStyle(.secondary)
                            .lineLimit(6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(Color.primary.opacity(0.05))
                            )
                    }
                    HStack(spacing: 10) {
                        Button(release.downloadURL != nil ? "Install & Relaunch" : "Download Update") {
                            update.installAvailable()
                        }
                        .buttonStyle(.borderedProminent)
                        .pointer()
                        Link("Release notes", destination: release.releasePageURL)
                            .font(.system(size: 12))
                            .pointer()
                    }
                }
                .padding(.vertical, 2)
            case .downloading(let release, let progress):
                VStack(alignment: .leading, spacing: 6) {
                    Text("Downloading Pano \(release.version)…")
                    if let progress {
                        ProgressView(value: progress)
                    } else {
                        ProgressView()
                    }
                }
            case .installing(let release):
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Verifying and installing Pano \(release.version)…")
                        .foregroundStyle(.secondary)
                }
            case .openedInstaller(let release, let message):
                VStack(alignment: .leading, spacing: 6) {
                    Text(message)
                        .font(.system(size: 12))
                    Link("Release notes", destination: release.releasePageURL)
                        .font(.system(size: 12))
                        .pointer()
                }
            case .failed(let message, let fallbackURL):
                VStack(alignment: .leading, spacing: 8) {
                    Text(message)
                        .font(.system(size: 12))
                        .foregroundStyle(.orange)
                    HStack(spacing: 10) {
                        Button("Try Again") { update.checkNow() }
                            .pointer()
                        if let fallbackURL {
                            Link("Open Releases", destination: fallbackURL)
                                .font(.system(size: 12))
                                .pointer()
                        }
                    }
                }
            }

            Toggle(
                "Check for updates automatically",
                isOn: toggle(\.automaticallyChecksForUpdates, { update.setAutomaticChecks($0) })
            )
        }
    }

    private static let websiteURL = URL(string: "https://pano-app.com") ?? URL(fileURLWithPath: "/")
    private static let githubURL = URL(string: "https://github.com/theshiver/pano-app") ?? URL(fileURLWithPath: "/")
    private static let autoPasteGuideURL =
        URL(string: "https://pano-app.com/auto-paste-setup/") ?? URL(fileURLWithPath: "/")

    // MARK: Helpers

    private func note(_ text: String) -> some View {
        Text(text).font(.system(size: 11)).foregroundStyle(.secondary)
    }

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
