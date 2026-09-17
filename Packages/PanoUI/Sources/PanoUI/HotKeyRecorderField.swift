import AppKit
import Carbon.HIToolbox
import SwiftUI

/// A control that records a global-hotkey combination. Click it, press a shortcut with at least one
/// modifier, and it reports the virtual key code, the Carbon modifier mask, and a display string.
/// Escape cancels. Built in AppKit because SwiftUI does not surface raw key codes.
public struct HotKeyRecorderField: NSViewRepresentable {
    private let display: String
    private let onRecorded: (UInt32, UInt32, String) -> Void

    public init(display: String, onRecorded: @escaping (UInt32, UInt32, String) -> Void) {
        self.display = display
        self.onRecorded = onRecorded
    }

    public func makeNSView(context: Context) -> RecorderView {
        RecorderView(display: display, onRecorded: onRecorded)
    }

    public func updateNSView(_ view: RecorderView, context: Context) {
        view.update(display: display)
    }

    public final class RecorderView: NSButton {
        private var recording = false
        private var display: String
        private let onRecorded: (UInt32, UInt32, String) -> Void

        init(display: String, onRecorded: @escaping (UInt32, UInt32, String) -> Void) {
            self.display = display
            self.onRecorded = onRecorded
            super.init(frame: .zero)
            bezelStyle = .rounded
            setButtonType(.momentaryPushIn)
            title = display
            target = self
            action = #selector(startRecording)
            setAccessibilityLabel("Record global shortcut")
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { nil }

        func update(display: String) {
            self.display = display
            if !recording { title = display }
        }

        @objc private func startRecording() {
            recording = true
            title = String(localized: "Press keys…")
            window?.makeFirstResponder(self)
        }

        public override var acceptsFirstResponder: Bool { true }

        public override func keyDown(with event: NSEvent) {
            guard recording else {
                super.keyDown(with: event)
                return
            }
            if event.keyCode == UInt16(kVK_Escape) {
                cancel()
                return
            }
            let carbon = Self.carbonModifiers(event.modifierFlags)
            guard carbon != 0 else { return }  // require at least one modifier
            let text = Self.displayString(keyCode: event.keyCode, modifiers: event.modifierFlags, event: event)
            recording = false
            title = text
            onRecorded(UInt32(event.keyCode), carbon, text)
        }

        private func cancel() {
            recording = false
            title = display
            window?.makeFirstResponder(nil)
        }

        static func carbonModifiers(_ flags: NSEvent.ModifierFlags) -> UInt32 {
            var result: UInt32 = 0
            if flags.contains(.command) { result |= UInt32(cmdKey) }
            if flags.contains(.shift) { result |= UInt32(shiftKey) }
            if flags.contains(.option) { result |= UInt32(optionKey) }
            if flags.contains(.control) { result |= UInt32(controlKey) }
            return result
        }

        static func displayString(keyCode: UInt16, modifiers: NSEvent.ModifierFlags, event: NSEvent) -> String {
            var glyphs = ""
            if modifiers.contains(.control) { glyphs += "⌃" }
            if modifiers.contains(.option) { glyphs += "⌥" }
            if modifiers.contains(.shift) { glyphs += "⇧" }
            if modifiers.contains(.command) { glyphs += "⌘" }
            let key = event.charactersIgnoringModifiers?.uppercased() ?? ""
            let printable = key.first.map { $0.isLetter || $0.isNumber || $0.isPunctuation } ?? false
            return glyphs + (printable ? key : "key\(keyCode)")
        }
    }
}
