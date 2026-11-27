import Foundation

@MainActor
@Observable
public final class SettingsNavigation {
    public var selectedTab: SettingsTab

    public init(selectedTab: SettingsTab = .general) {
        self.selectedTab = selectedTab
    }
}
