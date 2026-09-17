# ADR 0003 — Auto-paste through synthetic ⌘V (`CGEvent.post`) with Accessibility

**Status:** accepted · 2026-09-17 · supersedes the 2026-09-16 version of this
file, which chose Apple Events → System Events and was disproved by the week 0
spike.

## Context

Pasting back into the app the user was in is the core interaction. The Mac App
Store requires the App Sandbox. The original version of this ADR was written
from a feasibility report, not from source or measurement, and got two facts
wrong. Both were found in the week 0 spike (`spike/SpikePaste`, outside the
repo) on macOS 27.0 with App Sandbox on, and cross-checked against Maccy's
source (sandboxed, on the Mac App Store, `Maccy/Clipboard.swift`,
`Maccy.entitlements`, commit of 2026-09-04).

## What the spike found

| Claim in the old ADR | Reality |
|---|---|
| `com.apple.security.automation.apple-events` is enough for a sandboxed app to script System Events | No. `appleeventsd` refuses the target lookup (`denied due to sandboxing`), surfaced as `-600 Application isn't running`, no dialog. It also needs `com.apple.security.temporary-exception.apple-events` for `com.apple.systemevents`. |
| The user sees one ordinary TCC dialog | Two. `keystroke` in System Events fails with `1002 not allowed to send keystrokes` until the *sender* is trusted for Accessibility. Automation dialog, then the "would like to control this Mac" prompt. |
| `CGEvent.post` gets rejected under 2.4.5 | Maccy ships exactly that, sandboxed, on the Mac App Store, with only `com.apple.security.app-sandbox` in its entitlements. |
| Snapshot the pasteboard, paste, restore after ~100 ms | Maccy does not restore anything. The chosen item becomes the clipboard, which is what a clipboard manager user expects. The restore loop was invented, and it is where the bugs were (type order, Finder's private `noderef` type, `dyn.*` types). |

Both paths need Accessibility. Given that, Apple Events adds a temporary-exception
entitlement, a second dialog and 70–380 ms of AppleScript latency for nothing.

## Decision

Do what Maccy does.

- **Entitlements:** `com.apple.security.app-sandbox` only. No Apple Events, no
  temporary exceptions, no `NSAppleEventsUsageDescription`.
- **Permission:** Accessibility, granted by the user in System Settings. Checked
  with `AXIsProcessTrusted()`. **The prompt is not raised by
  `AXIsProcessTrustedWithOptions`** — on macOS 26/27 `tccd` logs
  *"Service kTCCServiceAccessibility does not allow prompting; returning
  Unknown"* and no dialog appears. The system disclosure prompt (*"Pano would
  like to control this Mac"*, with an *Open System Settings* button) is instead
  raised the first time the app **posts an event**, and macOS adds the app to
  the Device Control and Data Access list (unchecked) at that moment. So the
  onboarding trigger is attempting the paste, not a permission API. Verified on
  macOS 27.0, 2026-09-17.
- **Onboarding flow:** post ⌘V once → system shows the prompt and lists Pano →
  user opens Settings and flips the one toggle → poll `AXIsProcessTrusted()` and
  continue. There is no API to grant Accessibility inline; every clipboard
  manager on the Mac works this way. Pair the system prompt with our own button
  that deep-links to the pane (`x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility`,
  confirmed to open Device Control and Data Access on macOS 27).
- **Paste:** write the item to `NSPasteboard.general`, hide the panel so the
  previous app regains key focus, post ⌘V key-down and key-up with
  `CGEvent(keyboardEventSource:virtualKey:keyDown:)` on `.cgSessionEventTap`.
  Resolve the key code for the current keyboard layout (Maccy uses the `Sauce`
  package; whether Pano needs a dependency or a `TISCopyCurrentKeyboardLayoutInputSource`
  lookup is decided when `PasteService` is written, with an ADR if it is a dependency).
- **No restore.** The item stays on the clipboard. The capture loop sees the
  change and moves the item to the top of history instead of inserting a duplicate
  (hash match, see `03-data-model.md`).
- **What is stored per item:** the whitelisted types only —
  `public.file-url`, `public.html`, `public.png`, `public.rtf`,
  `public.utf8-plain-text`, `public.tiff` — in the order the source app listed
  them. `dyn.*` types and everything else are dropped. Each file URL is written
  back as its own `NSPasteboardItem` via `writeObjects`; other types go on the
  first item with `setData`. Verified round trips: rich text from Safari, pixels
  from Preview, one and two files from Finder into TextEdit, and files into a
  Finder folder.

## Consequences

- One permission dialog for auto-paste, and it is the one every clipboard
  manager on the Mac App Store already asks for.
- Latency: `CGEvent.post` returns in 1–17 ms. No AppleScript compile.
- **Auto-paste is a switchable feature that degrades to manual ⌘V.** Still the
  load-bearing part: without Accessibility, Pano puts the item on the clipboard
  and shows a hint. A review rejection costs a default setting, not the app.
- The review notes in `ops/app-store-connect.md` say the opposite of what this
  ADR now says and must be rewritten before submission.
- Storing TIFF for images is expensive (Preview put a multi-megabyte TIFF next to
  the PNG). Whether Pano stores PNG only is a `03-data-model.md` decision, not
  this ADR's.

## Lessons for the docs

Technical claims about macOS entitlements and review behaviour go in an ADR
only with a source: a header, a log line, a shipping app's entitlements file, or
a measurement. "A developer was rejected for X" without a link is a rumour.
