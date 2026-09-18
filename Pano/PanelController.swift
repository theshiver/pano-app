import AppKit
import PanoUI
import SwiftUI

/// Owns the non-activating `NSPanel` that hosts the SwiftUI panel (docs/adr/0005). A normal window
/// would activate the app and steal key focus from whatever the user was pasting into; this panel
/// takes keyboard focus without activating Pano, so the previous app stays frontmost for paste-back.
@MainActor
final class PanelController {
    private let panel: KeyablePanel
    private var model: PanelModel?
    private var keyMonitor: Any?
    private let prefs: Preferences

    init(prefs: Preferences) {
        self.prefs = prefs
        panel = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 440),
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: true
        )
        configure()
    }

    private func configure() {
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isFloatingPanel = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.animationBehavior = .none
    }

    func setContent(_ view: PanelView, model: PanelModel) {
        self.model = model
        panel.contentView = NSHostingView(rootView: view)
    }

    var isVisible: Bool { panel.isVisible }

    func show() {
        installKeyMonitor()
        positionNearCursor()
        panel.alphaValue = 0
        panel.makeKeyAndOrderFront(nil)
        // 140 ms open, slight fade (docs/05-design.md). Reduce Motion collapses it to instant.
        let reduce = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        NSAnimationContext.runAnimationGroup { context in
            context.duration = reduce ? 0 : 0.14
            panel.animator().alphaValue = 1
        }
    }

    func hide() {
        removeKeyMonitor()
        panel.orderOut(nil)
    }

    /// The search field's text editor swallows Backspace (and, since the rail gained buttons, the
    /// arrow keys) before SwiftUI's `onKeyPress` can see them, so those are handled here, ahead of
    /// the responder chain. Only ⌘⌫ deletes, never a plain Backspace — otherwise clearing the search
    /// query one character too far would destroy a clip. Runs only while the panel is visible.
    private func installKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.panel.isVisible else { return event }
            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            switch event.keyCode {
            case 51 where modifiers.contains(.command):  // ⌘⌫
                self.model?.deleteSelected()
                return nil  // consume, so the field editor does not also act on it
            case 125 where modifiers.isEmpty:  // ↓ — handled here too: the field editor or a rail
                self.model?.moveSelection(by: 1)  // control can swallow arrows before SwiftUI's onKeyPress
                return nil
            case 126 where modifiers.isEmpty:  // ↑
                self.model?.moveSelection(by: -1)
                return nil
            default:
                return event
            }
        }
    }

    private func removeKeyMonitor() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
    }

    /// Positions on the screen containing the mouse, then either biased toward the cursor or centred,
    /// per the user's preference, clamped inside the visible frame (docs/adr/0005).
    private func positionNearCursor() {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return }
        let size = panel.frame.size
        var origin: NSPoint
        switch prefs.panelPosition {
        case .nearCursor:
            origin = NSPoint(x: mouse.x - size.width / 2, y: mouse.y - size.height * 0.75)
        case .activeScreenCentre:
            origin = NSPoint(
                x: visible.midX - size.width / 2,
                y: visible.midY - size.height / 2
            )
        }
        origin.x = min(max(visible.minX + 8, origin.x), visible.maxX - size.width - 8)
        origin.y = min(max(visible.minY + 8, origin.y), visible.maxY - size.height - 8)
        panel.setFrameOrigin(origin)
    }
}

/// A non-activating panel must still be allowed to become key, or the search field never gets
/// keyboard focus. Borderless windows return false by default, so override it.
private final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}
