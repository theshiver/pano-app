import SwiftUI

/// The preferences window. Binds to `Preferences` (persisted in UserDefaults); the side-effectful
/// changes — retention applied to the store, launch-at-login registration — are handled by the app
/// through the injected closures so PanoUI stays free of the store and ServiceManagement.
public struct SettingsView: View {
    @Bindable private var prefs: Preferences
    private let onRetentionChanged: () -> Void
    private let onLaunchAtLoginChanged: (Bool) -> Void

    public init(
        prefs: Preferences,
        onRetentionChanged: @escaping () -> Void,
        onLaunchAtLoginChanged: @escaping (Bool) -> Void
    ) {
        self.prefs = prefs
        self.onRetentionChanged = onRetentionChanged
        self.onLaunchAtLoginChanged = onLaunchAtLoginChanged
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
                Picker("Panel position", selection: $prefs.panelPosition) {
                    Text("Near the cursor").tag(PanelPosition.nearCursor)
                    Text("Centre of the active screen").tag(PanelPosition.activeScreenCentre)
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
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 340)
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
