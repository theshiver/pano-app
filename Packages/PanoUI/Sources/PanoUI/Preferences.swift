import Foundation
import PanoStore

public enum PanelPosition: String, CaseIterable, Sendable {
    case nearCursor
    case activeScreenCentre
}

/// User preferences, backed by `UserDefaults`. The single source of truth for the plain settings;
/// the app reads `panelPosition` when showing the panel and applies the retention values to the
/// store. Launch-at-login is a bool here; the actual registration is done by the app target.
@MainActor
@Observable
public final class Preferences {
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var panelPosition: PanelPosition {
        get { defaults.string(forKey: "panelPosition").flatMap(PanelPosition.init) ?? .nearCursor }
        set { defaults.set(newValue.rawValue, forKey: "panelPosition") }
    }

    // Retention, in user-facing units. Defaults match RetentionRules.
    public var retentionSecretHours: Int {
        get { defaults.object(forKey: "retentionSecretHours") as? Int ?? 1 }
        set { defaults.set(newValue, forKey: "retentionSecretHours") }
    }
    public var retentionImageDays: Int {
        get { defaults.object(forKey: "retentionImageDays") as? Int ?? 7 }
        set { defaults.set(newValue, forKey: "retentionImageDays") }
    }
    public var retentionOtherDays: Int {
        get { defaults.object(forKey: "retentionOtherDays") as? Int ?? 30 }
        set { defaults.set(newValue, forKey: "retentionOtherDays") }
    }

    public var launchAtLogin: Bool {
        get { defaults.bool(forKey: "launchAtLogin") }
        set { defaults.set(newValue, forKey: "launchAtLogin") }
    }

    public var retentionRules: RetentionRules {
        var rules = RetentionRules()
        rules.secret = TimeInterval(retentionSecretHours) * 3600
        rules.image = TimeInterval(retentionImageDays) * 86_400
        rules.other = TimeInterval(retentionOtherDays) * 86_400
        return rules
    }
}
