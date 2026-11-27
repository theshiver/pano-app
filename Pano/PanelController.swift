import AppKit
import PanoCore
import PanoUI
import SwiftUI

@MainActor
final class PanelController: NSObject, NSWindowDelegate {
    private let panel: KeyablePanel
    private var model: PanelModel?
    private var keyMonitor: Any?
    private var outsideClickMonitor: Any?
    private var isHiding = false
    private let prefs: Preferences

    init(prefs: Preferences) {
        self.prefs = prefs
        let width = max(CGFloat(prefs.panelWidth), Theme.minWindowWidth)
        let height = max(CGFloat(prefs.panelHeight), Theme.minWindowHeight)
        panel = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless, .resizable],
            backing: .buffered,
            defer: true
        )
        super.init()
        configure()
    }

    private func configure() {
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isFloatingPanel = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovable = true
        panel.minSize = NSSize(width: Theme.minWindowWidth, height: Theme.minWindowHeight)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.animationBehavior = .none
        panel.delegate = self
    }

    func setContent(_ view: PanelView, model: PanelModel) {
        self.model = model
        panel.contentView = NSHostingView(rootView: view)
    }

    var isVisible: Bool { panel.isVisible }

    func show() {
        isHiding = false
        installMonitors()
        positionNearCursor()
        panel.alphaValue = 0
        panel.makeKeyAndOrderFront(nil)
        model?.requestSearchFocus()
        model?.activate()
        let reduce = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        NSAnimationContext.runAnimationGroup { context in
            context.duration = reduce ? 0 : 0.14
            panel.animator().alphaValue = 1
        }
    }

    func hide(animated: Bool = true) {
        removeMonitors()
        guard panel.isVisible, !isHiding else { return }
        isHiding = true
        let reduce = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        if !animated || reduce {
            panel.orderOut(nil)
            panel.alphaValue = 1
            isHiding = false
            return
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.08
            panel.animator().alphaValue = 0
        } completionHandler: { [weak self, weak panel] in
            Task { @MainActor in
                panel?.orderOut(nil)
                panel?.alphaValue = 1
                self?.isHiding = false
            }
        }
    }

    func windowDidResignKey(_ notification: Notification) {
        if panel.childWindows?.isEmpty ?? true {
            hide()
        }
    }

    func windowDidResize(_ notification: Notification) {
        let size = panel.frame.size
        guard size.width >= Theme.minWindowWidth, size.height >= Theme.minWindowHeight else { return }
        prefs.panelWidth = Double(size.width)
        prefs.panelHeight = Double(size.height)
    }

    private func installMonitors() {
        if keyMonitor == nil {
            keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self, self.panel.isVisible else { return event }
                let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
                switch event.keyCode {
                case 43 where modifiers == .command:  // ⌘,
                    self.model?.openSettings()
                    return nil
                case 51 where modifiers.contains(.command):  // ⌘⌫
                    self.model?.deleteSelected()
                    return nil
                case 125 where modifiers.isEmpty:  // ↓
                    self.model?.moveSelection(by: 1)
                    return nil
                case 126 where modifiers.isEmpty:  // ↑
                    self.model?.moveSelection(by: -1)
                    return nil
                default:
                    return event
                }
            }
        }
        if outsideClickMonitor == nil {
            outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) {
                [weak self] _ in
                Task { @MainActor in
                    guard let self, self.panel.isVisible else { return }
                    let point = NSEvent.mouseLocation
                    let insidePanel = self.panel.frame.contains(point)
                    let insideChild = (self.panel.childWindows ?? []).contains { $0.frame.contains(point) }
                    if !insidePanel && !insideChild {
                        self.hide()
                    }
                }
            }
        }
    }

    private func removeMonitors() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
        if let outsideClickMonitor { NSEvent.removeMonitor(outsideClickMonitor) }
        outsideClickMonitor = nil
    }

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

private final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}
