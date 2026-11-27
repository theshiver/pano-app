import AppKit
import Carbon.HIToolbox
import SwiftUI

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

        public override func resignFirstResponder() -> Bool {
            if recording {
                recording = false
                title = display
            }
            return super.resignFirstResponder()
        }

        public override func resetCursorRects() {
            addCursorRect(bounds, cursor: .pointingHand)
        }

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
            guard carbon != 0 else { return }
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

        public static func displayString(keyCode: UInt16, modifiers: NSEvent.ModifierFlags, event: NSEvent) -> String {
            displayString(
                keyCode: keyCode, modifiers: modifiers, charactersIgnoringModifiers: event.charactersIgnoringModifiers)
        }

        static func displayString(
            keyCode: UInt16, modifiers: NSEvent.ModifierFlags, charactersIgnoringModifiers: String?
        ) -> String {
            var glyphs = ""
            if modifiers.contains(.control) { glyphs += "⌃" }
            if modifiers.contains(.option) { glyphs += "⌥" }
            if modifiers.contains(.shift) { glyphs += "⇧" }
            if modifiers.contains(.command) { glyphs += "⌘" }
            if let special = specialKeyName(keyCode) {
                return glyphs + special
            }
            let key = charactersIgnoringModifiers?.uppercased() ?? ""
            let printable = key.first.map { $0.isLetter || $0.isNumber || $0.isPunctuation || $0.isSymbol } ?? false
            return glyphs + (printable ? key : "key\(keyCode)")
        }

        private static func specialKeyName(_ keyCode: UInt16) -> String? {
            switch Int(keyCode) {
            case kVK_Space: return "Space"
            case kVK_Return: return "↩"
            case kVK_Tab: return "⇥"
            case kVK_Delete: return "⌫"
            case kVK_ForwardDelete: return "⌦"
            case kVK_LeftArrow: return "←"
            case kVK_RightArrow: return "→"
            case kVK_UpArrow: return "↑"
            case kVK_DownArrow: return "↓"
            case kVK_Home: return "↖"
            case kVK_End: return "↘"
            case kVK_PageUp: return "⇞"
            case kVK_PageDown: return "⇟"
            case kVK_F1: return "F1"
            case kVK_F2: return "F2"
            case kVK_F3: return "F3"
            case kVK_F4: return "F4"
            case kVK_F5: return "F5"
            case kVK_F6: return "F6"
            case kVK_F7: return "F7"
            case kVK_F8: return "F8"
            case kVK_F9: return "F9"
            case kVK_F10: return "F10"
            case kVK_F11: return "F11"
            case kVK_F12: return "F12"
            default: return nil
            }
        }
    }
}
