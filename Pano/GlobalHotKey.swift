import Carbon.HIToolbox
import Foundation

/// Registers a system-wide hotkey with Carbon's `RegisterEventHotKey`, which works inside the App
/// Sandbox and raises no permission prompt — unlike Input Monitoring (docs/04-permissions.md).
/// Default: ⌘⇧V.
final class GlobalHotKey {
    /// Carries the action across the C function-pointer boundary. A final class with an immutable
    /// `@Sendable` closure is itself Sendable, so no `@unchecked` is needed. The action hops to the
    /// main actor because the panel is main-isolated.
    private final class Box: Sendable {
        let action: @Sendable () -> Void
        init(_ action: @escaping @Sendable () -> Void) { self.action = action }
    }

    private var ref: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private let box: Box

    init(
        keyCode: UInt32 = UInt32(kVK_ANSI_V),
        modifiers: UInt32 = UInt32(cmdKey | shiftKey),
        action: @escaping @Sendable () -> Void
    ) {
        box = Box(action)

        let id = EventHotKeyID(signature: OSType(0x50_41_4E_4F), id: 1)  // 'PANO'
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)
        )

        let userData = Unmanaged.passUnretained(box).toOpaque()
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let userData, let event else { return noErr }
                var hkID = EventHotKeyID()
                GetEventParameter(
                    event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                    nil, MemoryLayout<EventHotKeyID>.size, nil, &hkID
                )
                if hkID.id == 1 {
                    Unmanaged<Box>.fromOpaque(userData).takeUnretainedValue().action()
                }
                return noErr
            },
            1, &eventType, userData, &handler
        )
        RegisterEventHotKey(keyCode, modifiers, id, GetApplicationEventTarget(), 0, &ref)
    }

    deinit {
        if let ref { UnregisterEventHotKey(ref) }
        if let handler { RemoveEventHandler(handler) }
    }
}
