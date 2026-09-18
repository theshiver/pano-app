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
    private var state: OnboardingState?
    private var hosting: NSHostingView<OnboardingView>?

    /// Accessibility stays granted on a dev machine, so the not-yet-trusted state can only be seen by
    /// pretending: `PANO_FAKE_UNTRUSTED=1` (Debug builds) shows onboarding as a first run would, and
    /// `PANO_FAKE_UNTRUSTED=flip` flips to trusted after ten seconds to exercise the transition.
    private let launchedAt = Date()
    private var isTrusted: Bool {
        #if DEBUG
            switch ProcessInfo.processInfo.environment["PANO_FAKE_UNTRUSTED"] {
            case "1": return false
            case "flip": return Date().timeIntervalSince(launchedAt) > 10
            default: break
            }
        #endif
        return PasteService.isAccessibilityTrusted
    }

    /// Shows onboarding only when auto-paste is not yet available. Returns whether it was shown.
    @discardableResult
    func showIfNeeded() -> Bool {
        guard !isTrusted else { return false }
        show()
        return true
    }

    func show() {
        let window =
            self.window
            ?? NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: OnboardingView.width, height: 560),
                styleMask: [.titled, .closable, .fullSizeContentView],
                backing: .buffered, defer: false
            )
        window.isReleasedWhenClosed = false
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        let state = OnboardingState(isTrusted: isTrusted)
        self.state = state
        let hosting = NSHostingView(rootView: makeView(state))
        hosting.sizingOptions = [.preferredContentSize]
        self.hosting = hosting
        window.contentView = hosting
        window.setContentSize(hosting.fittingSize)
        window.center()
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
        startPolling()
    }

    private func makeView(_ state: OnboardingState) -> OnboardingView {
        OnboardingView(
            state: state,
            onEnable: {
                PasteService.triggerAccessibilityPrompt()
                Self.openAccessibilitySettings()
            },
            onOpenSettings: { Self.openAccessibilitySettings() },
            onSkip: { [weak self] in self?.close() }
        )
    }

    /// Polls the permission so the window flips to "enabled" the moment the user turns the switch on
    /// in System Settings; the view animates the change.
    private func startPolling() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, let state = self.state else { return }
                let trusted = self.isTrusted
                guard trusted != state.isTrusted else { return }
                state.isTrusted = trusted
                self.fitWindowToContent()
            }
        }
    }

    /// The enabled state swaps the skip links for a full-width button, so the content gets taller;
    /// grow the window from its top edge once SwiftUI has laid the new content out.
    private func fitWindowToContent() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            MainActor.assumeIsolated {
                guard let self, let window = self.window, let hosting = self.hosting else { return }
                let size = hosting.fittingSize
                var frame = window.frame
                let delta = size.height - window.contentRect(forFrameRect: frame).height
                frame.origin.y -= delta
                frame.size.height += delta
                window.setFrame(frame, display: true, animate: true)
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
