import Carbon.HIToolbox
import Foundation
import PanoStore

public enum PanelPosition: String, CaseIterable, Sendable {
    case nearCursor
    case activeScreenCentre
}

/// User preferences. Stored properties (so `@Observable` can track them and SwiftUI updates when
/// they change from anywhere), loaded from `UserDefaults` at init and written back on each set.
@MainActor
@Observable
public final class Preferences {
    @ObservationIgnored private let defaults: UserDefaults

    public var panelPosition: PanelPosition {
        didSet { defaults.set(panelPosition.rawValue, forKey: Key.panelPosition) }
    }
    public var retentionSecretHours: Int {
        didSet { defaults.set(retentionSecretHours, forKey: Key.retentionSecretHours) }
    }
    public var retentionImageDays: Int { didSet { defaults.set(retentionImageDays, forKey: Key.retentionImageDays) } }
    public var retentionOtherDays: Int { didSet { defaults.set(retentionOtherDays, forKey: Key.retentionOtherDays) } }
    public var launchAtLogin: Bool { didSet { defaults.set(launchAtLogin, forKey: Key.launchAtLogin) } }
    public var ocrEnabled: Bool { didSet { defaults.set(ocrEnabled, forKey: Key.ocrEnabled) } }
    public var maskSecrets: Bool { didSet { defaults.set(maskSecrets, forKey: Key.maskSecrets) } }
    public var highlightCode: Bool { didSet { defaults.set(highlightCode, forKey: Key.highlightCode) } }
    public var syntaxTheme: String { didSet { defaults.set(syntaxTheme, forKey: Key.syntaxTheme) } }

    /// Global hotkey: a virtual key code and Carbon modifier mask, plus a display string like "⌘⇧V".
    public var hotKeyCode: UInt32 { didSet { defaults.set(Int(hotKeyCode), forKey: Key.hotKeyCode) } }
    public var hotKeyModifiers: UInt32 { didSet { defaults.set(Int(hotKeyModifiers), forKey: Key.hotKeyModifiers) } }
    public var hotKeyDisplay: String { didSet { defaults.set(hotKeyDisplay, forKey: Key.hotKeyDisplay) } }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        panelPosition = defaults.string(forKey: Key.panelPosition).flatMap(PanelPosition.init) ?? .nearCursor
        retentionSecretHours = defaults.object(forKey: Key.retentionSecretHours) as? Int ?? 1
        retentionImageDays = defaults.object(forKey: Key.retentionImageDays) as? Int ?? 7
        retentionOtherDays = defaults.object(forKey: Key.retentionOtherDays) as? Int ?? 30
        launchAtLogin = defaults.bool(forKey: Key.launchAtLogin)
        ocrEnabled = defaults.object(forKey: Key.ocrEnabled) as? Bool ?? true
        maskSecrets = defaults.object(forKey: Key.maskSecrets) as? Bool ?? true
        highlightCode = defaults.object(forKey: Key.highlightCode) as? Bool ?? true
        syntaxTheme = defaults.string(forKey: Key.syntaxTheme) ?? "atom-one-dark"
        hotKeyCode = UInt32(defaults.object(forKey: Key.hotKeyCode) as? Int ?? kVK_ANSI_V)
        hotKeyModifiers = UInt32(defaults.object(forKey: Key.hotKeyModifiers) as? Int ?? (cmdKey | shiftKey))
        hotKeyDisplay = defaults.string(forKey: Key.hotKeyDisplay) ?? "⌘⇧V"
    }

    public var retentionRules: RetentionRules {
        var rules = RetentionRules()
        rules.secret = TimeInterval(retentionSecretHours) * 3600
        rules.image = TimeInterval(retentionImageDays) * 86_400
        rules.other = TimeInterval(retentionOtherDays) * 86_400
        return rules
    }

    /// A curated set of Highlightr (highlight.js) themes offered in Settings.
    public static let syntaxThemes: [(id: String, label: String)] = [
        ("atom-one-dark", "Atom One Dark"), ("atom-one-light", "Atom One Light"),
        ("github-dark", "GitHub Dark"), ("github", "GitHub Light"),
        ("monokai", "Monokai"), ("dracula", "Dracula"), ("nord", "Nord"),
        ("tokyo-night-dark", "Tokyo Night"), ("xcode-dark", "Xcode Dark"), ("xcode", "Xcode Light"),
        ("solarized-dark", "Solarized Dark"), ("solarized-light", "Solarized Light"),
    ]

    private enum Key {
        static let panelPosition = "panelPosition"
        static let retentionSecretHours = "retentionSecretHours"
        static let retentionImageDays = "retentionImageDays"
        static let retentionOtherDays = "retentionOtherDays"
        static let launchAtLogin = "launchAtLogin"
        static let ocrEnabled = "ocrEnabled"
        static let maskSecrets = "maskSecrets"
        static let highlightCode = "highlightCode"
        static let syntaxTheme = "syntaxTheme"
        static let hotKeyCode = "hotKeyCode"
        static let hotKeyModifiers = "hotKeyModifiers"
        static let hotKeyDisplay = "hotKeyDisplay"
    }
}
