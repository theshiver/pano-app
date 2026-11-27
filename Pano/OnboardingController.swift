import AppKit
import PanoUI
import SwiftUI

@MainActor
final class OnboardingController {
    private let prefs: Preferences
    private let supportsAutoPaste: Bool
    private let onComplete: (_ loadSamples: Bool, _ enableAutoPaste: Bool) -> Void
    private var window: NSWindow?

    init(
        prefs: Preferences,
        supportsAutoPaste: Bool,
        onComplete: @escaping (_ loadSamples: Bool, _ enableAutoPaste: Bool) -> Void
    ) {
        self.prefs = prefs
        self.supportsAutoPaste = supportsAutoPaste
        self.onComplete = onComplete
    }

    private var forceOnboarding: Bool {
        #if DEBUG
            return ProcessInfo.processInfo.environment["PANO_FORCE_ONBOARDING"] == "1"
        #else
            return false
        #endif
    }

    @discardableResult
    func showIfNeeded() -> Bool {
        if forceOnboarding {
            show()
            return true
        }
        guard !prefs.hasSeenOnboarding else { return false }
        prefs.hasSeenOnboarding = true
        show()
        return true
    }

    func show() {
        let window =
            self.window
            ?? NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: OnboardingView.width, height: 460),
                styleMask: [.titled, .closable, .fullSizeContentView],
                backing: .buffered, defer: false
            )
        window.isReleasedWhenClosed = false
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        let hosting = NSHostingView(
            rootView: OnboardingView(
                hotKeyDisplay: prefs.hotKeyDisplay,
                supportsAutoPaste: supportsAutoPaste
            ) { [weak self] loadSamples, enableAutoPaste in
                self?.onComplete(loadSamples, enableAutoPaste)
                self?.close()
            }
        )
        hosting.sizingOptions = [.preferredContentSize, .intrinsicContentSize]
        window.contentView = hosting
        window.setContentSize(hosting.fittingSize)
        window.center()
        self.window = window
        NSRunningApplication.current.activate(options: [.activateAllWindows])
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
        DispatchQueue.main.async {
            NSApp.activate()
            window.makeKeyAndOrderFront(nil)
        }
    }

    private func close() {
        window?.close()
        window = nil
    }
}
