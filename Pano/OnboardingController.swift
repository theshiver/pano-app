import AppKit
import PanoCore
import PanoUI
import SwiftUI

/// Shows the first-run window when Accessibility is not yet granted, and polls for the grant so the
/// window can flip to "enabled" and let the user continue. Auto-paste is optional, so the window is
/// dismissible at any time (docs/adr/0003).
@MainActor
final class OnboardingController {
    private var window: NSWindow?
    private var pollTimer: Timer?

    /// Shows onboarding only when auto-paste is not yet available. Returns whether it was shown.
    @discardableResult
    func showIfNeeded() -> Bool {
        guard !PasteService.isAccessibilityTrusted else { return false }
        show()
        return true
    }

    func show() {
        let window =
            self.window
            ?? NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 420, height: 360),
                styleMask: [.titled, .closable, .fullSizeContentView],
                backing: .buffered, defer: false
            )
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.center()
        window.contentView = NSHostingView(rootView: makeView())
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
        startPolling()
    }

    private func makeView() -> OnboardingView {
        OnboardingView(
            isTrusted: PasteService.isAccessibilityTrusted,
            onEnable: {
                PasteService.triggerAccessibilityPrompt()
                Self.openAccessibilitySettings()
            },
            onOpenSettings: { Self.openAccessibilitySettings() },
            onSkip: { [weak self] in self?.close() }
        )
    }

    /// Re-render on each poll so the window reflects the live permission state and auto-updates the
    /// moment the user flips the switch in System Settings.
    private func startPolling() {
        pollTimer?.invalidate()
        var wasTrusted = PasteService.isAccessibilityTrusted
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, let window = self.window else { return }
                let trusted = PasteService.isAccessibilityTrusted
                if trusted != wasTrusted {
                    wasTrusted = trusted
                    window.contentView = NSHostingView(rootView: self.makeView())
                }
            }
        }
    }

    private func close() {
        pollTimer?.invalidate()
        pollTimer = nil
        window?.close()
        window = nil
    }

    static func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
        if let url { NSWorkspace.shared.open(url) }
    }
}
