import AppKit
import PanoCore
import PanoUI
import SwiftUI

/// The first-run window: teaches ⌘⇧V and *offers* auto-paste. Shown once per install, whatever the
/// permission state — it is not a permission gate. Nothing here asks macOS for anything until the
/// user presses "Turn on"; that is the only path in the app that raises the prompt (docs/adr/0003).
/// Once pressed, it polls so the row can flip to "on" while the user is in System Settings.
@MainActor
final class OnboardingController {
    private let prefs: Preferences
    private var window: NSWindow?
    private var pollTimer: Timer?
    private var state: OnboardingState?
    private var hosting: NSHostingView<OnboardingView>?

    init(prefs: Preferences) { self.prefs = prefs }

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

    /// True once the user has both asked for auto-paste and been granted the keystroke.
    private var isAutoPasteOn: Bool { prefs.autoPaste && isTrusted }

    /// The window is shown once per install and the flag lives in the app's sandbox container, which
    /// is TCC-protected — so on a dev machine there is no way to get a first run back from outside
    /// the app. `PANO_FORCE_ONBOARDING=1` (Debug builds) shows it anyway, without writing the flag.
    private var forceOnboarding: Bool {
        #if DEBUG
            return ProcessInfo.processInfo.environment["PANO_FORCE_ONBOARDING"] == "1"
        #else
            return false
        #endif
    }

    /// Shows the window once per install. Deliberately **not** gated on the permission: gating on it
    /// turned first run into a permission demand, which is what the 1.0 (3) review rejected.
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
                contentRect: NSRect(x: 0, y: 0, width: OnboardingView.width, height: 560),
                styleMask: [.titled, .closable, .fullSizeContentView],
                backing: .buffered, defer: false
            )
        window.isReleasedWhenClosed = false
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        let state = OnboardingState(isAutoPasteOn: isAutoPasteOn)
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
            onEnable: { [weak self] in
                // The one user-initiated path that asks macOS for anything. Record the choice first
                // so the paste path honours it the moment the switch is flipped.
                self?.prefs.autoPaste = true
                PasteService.triggerAccessibilityPrompt()
                PasteService.openSettingsPane()
            },
            onOpenSettings: { PasteService.openSettingsPane() },
            onSkip: { [weak self] in self?.close() }
        )
    }

    /// Polls the permission so the row flips to "on" the moment the user turns the switch on in
    /// System Settings; the view animates the change.
    private func startPolling() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, let state = self.state else { return }
                let on = self.isAutoPasteOn
                guard on != state.isAutoPasteOn else { return }
                state.isAutoPasteOn = on
                self.fitWindowToContent()
            }
        }
    }

    /// The "on" state swaps the skip links for a full-width button, so the content gets taller;
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

}
