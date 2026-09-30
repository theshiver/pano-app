import AppKit
import PanoUI
import SwiftUI

/// Shows `PasteHintView` after an ⏎ that only reached the clipboard, then fades it out.
///
/// The window is a non-activating borderless panel for the same reason the main panel is
/// (docs/adr/0005), and more so: the user is about to press ⌘V in their own app, so this must never
/// become key or the keystroke would land here.
@MainActor
final class PasteHintController {
    private let prefs: Preferences
    private var panel: NSPanel?
    private var hideTask: Task<Void, Never>?

    /// Long enough to read a sentence and reach the link.
    private static let visible = Duration.seconds(4)

    init(prefs: Preferences) { self.prefs = prefs }

    /// The hint only appears after a real ⏎ in the panel, which makes it awkward to look at while
    /// working on it. `PANO_SHOW_PASTE_HINT=1` (Debug builds) shows it a moment after launch.
    func showForDebugIfRequested() {
        #if DEBUG
            guard ProcessInfo.processInfo.environment["PANO_SHOW_PASTE_HINT"] == "1" else { return }
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1))
                self.show()
            }
        #endif
    }

    /// Call after every ⏎ in the panel. Silent once the user has answered "Don't remind me"; the
    /// preview footer still says `then ⌘V in your app` for anyone who forgets.
    func showIfNeeded() {
        guard !prefs.copyHintDismissed else { return }
        show()
    }

    private func show() {
        let view = PasteHintView(onDismiss: { [weak self] in
            self?.prefs.copyHintDismissed = true
            self?.hide()
        })

        let hosting = NSHostingView(rootView: view)
        hosting.sizingOptions = [.preferredContentSize, .intrinsicContentSize]

        let panel =
            self.panel
            ?? NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: PasteHintView.width, height: 1),
                styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
                backing: .buffered, defer: true
            )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false  // the view draws its own, inside its padding
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.animationBehavior = .none
        panel.contentView = hosting
        // Force the layout pass before measuring. `fittingSize` is `.zero` until SwiftUI has laid
        // the view out, and `sizingOptions` only corrects the window a run loop turn later — by
        // which time `position` has already centred a zero-width window, leaving the card hanging
        // off the middle of the screen instead of centred under it.
        hosting.layoutSubtreeIfNeeded()
        let size = hosting.fittingSize == .zero ? hosting.intrinsicContentSize : hosting.fittingSize
        panel.setContentSize(size)
        position(panel)
        self.panel = panel

        panel.alphaValue = 0
        panel.orderFrontRegardless()  // never makeKey: ⌘V must go to the user's app
        let reduce = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        NSAnimationContext.runAnimationGroup { context in
            context.duration = reduce ? 0 : 0.16
            panel.animator().alphaValue = 1
        }

        hideTask?.cancel()
        hideTask = Task { [weak self] in
            try? await Task.sleep(for: Self.visible)
            guard !Task.isCancelled else { return }
            self?.hide()
        }
    }

    /// Bottom centre of the screen the mouse is on, which is the screen the panel was just on.
    private func position(_ panel: NSPanel) {
        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
        guard let frame = screen?.visibleFrame else { return }
        let size = panel.frame.size
        panel.setFrameOrigin(
            NSPoint(x: frame.midX - size.width / 2, y: frame.minY + 24))
    }

    private func hide() {
        hideTask?.cancel()
        hideTask = nil
        guard let panel else { return }
        let reduce = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        NSAnimationContext.runAnimationGroup { context in
            context.duration = reduce ? 0 : 0.2
            panel.animator().alphaValue = 0
        } completionHandler: {
            panel.orderOut(nil)
        }
    }
}
