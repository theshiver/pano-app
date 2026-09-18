import SwiftUI

/// The preferences window. Binds to `Preferences` (persisted in UserDefaults); the side-effectful
/// changes — retention applied to the store, launch-at-login registration — are handled by the app
/// through the injected closures so PanoUI stays free of the store and ServiceManagement.
public struct SettingsView: View {
    @Bindable private var prefs: Preferences
    private let exclusion: ExclusionModel
    private let onRetentionChanged: () -> Void
    private let onLaunchAtLoginChanged: (Bool) -> Void
    private let onHotKeyChanged: () -> Void
    private let onOCRChanged: (Bool) -> Void

    public init(
        prefs: Preferences,
        exclusion: ExclusionModel,
        onRetentionChanged: @escaping () -> Void,
        onLaunchAtLoginChanged: @escaping (Bool) -> Void,
        onHotKeyChanged: @escaping () -> Void,
        onOCRChanged: @escaping (Bool) -> Void
    ) {
        self.prefs = prefs
        self.exclusion = exclusion
        self.onRetentionChanged = onRetentionChanged
        self.onLaunchAtLoginChanged = onLaunchAtLoginChanged
        self.onHotKeyChanged = onHotKeyChanged
        self.onOCRChanged = onOCRChanged
    }

    public var body: some View {
        Form {
            Section("General") {
                Toggle(
                    "Launch Pano at login",
                    isOn: Binding(
                        get: { prefs.launchAtLogin },
                        set: {
                            prefs.launchAtLogin = $0; onLaunchAtLoginChanged($0)
                        }
                    )
                )
                Toggle(
                    "Read text in images (OCR)",
                    isOn: Binding(
                        get: { prefs.ocrEnabled },
                        set: {
                            prefs.ocrEnabled = $0; onOCRChanged($0)
                        }
                    )
                )
                Picker("Panel position", selection: $prefs.panelPosition) {
                    Text("Near the cursor").tag(PanelPosition.nearCursor)
                    Text("Centre of the active screen").tag(PanelPosition.activeScreenCentre)
                }
                LabeledContent("Open shortcut") {
                    HotKeyRecorderField(display: prefs.hotKeyDisplay) { code, modifiers, display in
                        prefs.hotKeyCode = code
                        prefs.hotKeyModifiers = modifiers
                        prefs.hotKeyDisplay = display
                        onHotKeyChanged()
                    }
                    .frame(width: 120, height: 22)
                }
            }

            Section("History retention") {
                Stepper(
                    "Sensitive items: \(prefs.retentionSecretHours) hour\(prefs.retentionSecretHours == 1 ? "" : "s")",
                    value: retentionBinding(\.retentionSecretHours), in: 1...72
                )
                Stepper(
                    "Images: \(prefs.retentionImageDays) day\(prefs.retentionImageDays == 1 ? "" : "s")",
                    value: retentionBinding(\.retentionImageDays), in: 1...90
                )
                Stepper(
                    "Everything else: \(prefs.retentionOtherDays) day\(prefs.retentionOtherDays == 1 ? "" : "s")",
                    value: retentionBinding(\.retentionOtherDays), in: 1...365
                )
                Text("Pinned items are always kept, regardless of these limits.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Section("Excluded apps") {
                if exclusion.apps.isEmpty {
                    Text("Nothing copied from an excluded app is ever recorded.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
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
                            .accessibilityLabel("Remove \(app.displayName)")
                        }
                    }
                }
                Button("Add App…") { exclusion.add() }
            }
        }
        .formStyle(.grouped)
        .frame(width: 440, height: 460)
    }

    private func retentionBinding(_ keyPath: ReferenceWritableKeyPath<Preferences, Int>) -> Binding<Int> {
        Binding(
            get: { prefs[keyPath: keyPath] },
            set: {
                prefs[keyPath: keyPath] = $0; onRetentionChanged()
            }
        )
    }
}
