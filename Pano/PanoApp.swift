import SwiftUI

/// Menu-bar accessory (LSUIElement, no Dock icon, no windows of its own — docs/adr/0005).
/// All the real work is set up by the app delegate; the Settings scene exists only so the app
/// has a valid scene and a place for preferences later.
@main
struct PanoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
