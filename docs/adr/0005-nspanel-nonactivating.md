# ADR 0005 — The main panel is a non-activating NSPanel

**Status:** accepted · 2026-09-16

## Context

Pano's main surface appears over whatever the user is working in, and then pastes
back into it. A normal window, including a SwiftUI `Window` or `WindowGroup`,
activates its application when shown. The previously focused app loses key focus,
and there is nothing left to paste into.

## Decision

`NSPanel` with `.nonactivatingPanel`, hosting SwiftUI through `NSHostingView`.

Configuration: `level = .floating`, `hidesOnDeactivate = false`, collection
behaviour including `.canJoinAllSpaces` and `.fullScreenAuxiliary`. Positioned on
the screen containing the mouse, biased toward the cursor, clamped inside the
visible frame.

## Consequences

- SwiftUI cannot own the window. The app target creates and manages the panel;
  `PanoUI` supplies the content view.
- Keyboard handling needs care: a non-activating panel does not receive key events
  the way a normal key window does. The search field has to be made first
  responder explicitly when the panel is shown.
- Some SwiftUI focus and menu behaviours do not work as they would in a standard
  window. Where that bites, solve it in AppKit rather than fighting SwiftUI.
- The app is a menu-bar accessory: `LSUIElement` is true, there is no Dock icon
  and no main menu bar of its own.
