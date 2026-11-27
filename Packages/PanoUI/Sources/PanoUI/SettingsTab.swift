import Foundation

public enum SettingsTab: String, CaseIterable, Identifiable, Sendable {
    case general, history, privacy, about

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .general: return "General"
        case .history: return "History"
        case .privacy: return "Privacy"
        case .about: return "About"
        }
    }

    public var symbol: String {
        switch self {
        case .general: return "gearshape"
        case .history: return "clock.arrow.circlepath"
        case .privacy: return "hand.raised"
        case .about: return "info.circle"
        }
    }
}
