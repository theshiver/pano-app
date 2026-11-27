#if DIRECT_DISTRIBUTION
    import AppKit
    import Carbon.HIToolbox
    import Foundation

    @MainActor
    enum AutoPasteService {
        static var isTrusted: Bool { AXIsProcessTrusted() }

        static func pasteAfterHide(auto: Bool, settleDelay: Duration = .milliseconds(80)) async -> Bool {
            guard auto, AXIsProcessTrusted() else { return false }
            try? await Task.sleep(for: settleDelay)
            postCommandV()
            return true
        }

        static func openSettingsPane() {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }

        static func revealAppInFinder() {
            NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])
        }

        private static func postCommandV() {
            let source = CGEventSource(stateID: .combinedSessionState)
            let keyV = CGKeyCode(kVK_ANSI_V)
            guard let down = CGEvent(keyboardEventSource: source, virtualKey: keyV, keyDown: true),
                let up = CGEvent(keyboardEventSource: source, virtualKey: keyV, keyDown: false)
            else { return }
            down.flags = .maskCommand
            up.flags = .maskCommand
            down.post(tap: .cgSessionEventTap)
            up.post(tap: .cgSessionEventTap)
        }
    }
#endif
