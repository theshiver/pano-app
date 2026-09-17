import SwiftUI

@main
struct PanoApp: App {
    var body: some Scene {
        // Week 0 skeleton. The real UI is an NSPanel hosted from an AppDelegate (docs/adr/0005);
        // this window exists only to prove the paste path from inside the sandboxed app target.
        WindowGroup("Pano") {
            SkeletonView()
        }
    }
}
