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

- **Entitlements:** `com.apple.security.app-sandbox` plus
  `com.apple.security.files.user-selected.read-only` (added 2026-09-17 for the
  Settings app-picker and cross-launch file paste-back — a user-chosen file, no
  network implication). No Apple Events, no temporary exceptions, no
  `NSAppleEventsUsageDescription`.
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
  Finder folder. How these are stored (per-representation table, PNG over TIFF,
  64 KB inline threshold, file bookmarks) is in `03-data-model.md`.

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
  the PNG). Resolved in `03-data-model.md`: store PNG, drop TIFF when both are
  present.
- Cross-launch file paste-back may need a second entitlement
  (`files.user-selected.read-only`); flagged as an open decision in
  `03-data-model.md`, not taken here.

## Lessons for the docs

Technical claims about macOS entitlements and review behaviour go in an ADR
only with a source: a header, a log line, a shipping app's entitlements file, or
a measurement. "A developer was rejected for X" without a link is a rumour.

## Addendum — 2026-09-22: rejected under 2.4.5, auto-paste becomes opt-in

App Review rejected 1.0 (3) on 2026-09-21 under guideline 2.4.5: *"The app
requests access to Accessibility features on macOS but does not use these
features for accessibility purposes."* The attached screenshot was our own
onboarding window.

**What the decision above got right and kept:** the mechanism. `CGEvent.post`
with only `app-sandbox` in the entitlements is still the choice; nothing here
moves to Apple Events, and no entitlement is added.

**What was wrong was not the mechanism, it was that the app demanded it.** Three
things the consequences section of this ADR and `04-permissions.md` both
promised, and which were never built:

| Promised | Shipped in 1.0 (3) |
|---|---|
| "a switchable feature that degrades to manual ⌘V" | No setting existed anywhere; `PasteService.paste` posted ⌘V unconditionally |
| "shows a hint to press ⌘V" | `paste` returned the trust state; `AppDelegate` discarded it and showed nothing |
| "a review rejection costs a default setting" | There was no default to change |

So on first launch the app opened a window whose second row read *"Needs
Accessibility, so Pano can press ⌘V in the app you were in"*, with the grant
button bound to ⏎. The reviewer did not have to look for the violation.

**Change:** `Preferences.autoPaste`, default **off**; `paste(_:auto:)` posts
nothing when it is off; the preview footer says `copy` rather than `paste` when
⏎ will not reach the other app; onboarding shows once per install and offers the
feature instead of requiring it. Rules and invariants in `04-permissions.md`.

**Cost:** out of the box ⏎ is one keystroke short of the promise in the App Store
description, and that description needs rewriting either way
(`ops/appstore/metadata-1.0.md`).

**Still open:** whether this is enough for 2.4.5, or whether the Mac App Store
build has to drop the feature entirely. Not decided here. If it is dropped it is
a compile-time removal, not a default — a setting a reviewer can find and switch
on is the same rejection again.

## Second addendum — 2026-09-25: rejected again; never post untrusted, never prompt

1.0 (6), with auto-paste opt-in and off by default, was rejected under 2.4.5
with the same template. Opt-in did not matter.

**What the Mac App Store actually ships.** Checked on copies installed from the
Mac App Store (`codesign`, entitlements, `nm -u`; first-release dates from the
iTunes lookup API):

| App | First release | Links |
|---|---|---|
| Recopy | 2026-02-23 | `AXIsProcessTrusted(WithOptions)`, `CGEventCreateKeyboardEvent`, `CGEventPost` |
| Clipboard AI | 2026-03-23 | same |
| Pastebot 3 | 2026-07-28 | same + `CGRequestPostEventAccess` |
| Paste | 2015, updated 2026-09-21 | `AXIsProcessTrusted`, `CGEventCreateKeyboardEvent`, `CGEventPost` |

All sandboxed, none with Apple Events entitlements. So the mechanism and the
permission are not the problem; two of these are new apps from small
developers approved this year.

**The one behavioural difference found.** This ADR's original flow posted a
throwaway mouse event, and posted ⌘V without checking trust, precisely so macOS
would raise its own *"would like to control this Mac"* dialog and add Pano to the
list. The apps above check trust first and post nothing until it is granted;
they show their own message and open System Settings, and the user adds the app
with + (Can confirmed none of them appear in the list by themselves). The
rejection says the app *"requests access to Accessibility features"*; the system
dialog is the most literal form of a request, and only Pano produced it. This is
a hypothesis — App Review's process is not visible — but it is the only
difference we could find.

**Decision (supersedes the prompt/onboarding parts above):**

- `PasteService.paste` posts only behind `guard auto, AXIsProcessTrusted()`.
- `triggerAccessibilityPrompt()` is deleted. Pano never posts an event to obtain
  a prompt, and does not call `CGRequestPostEventAccess`.
- The user adds Pano manually. Settings shows three steps plus *Open System
  Settings* and *Show Pano in Finder*.
- Onboarding no longer mentions auto-paste. It is offered in context by the hint
  card after an ⏎ that only copied, which leads to those Settings steps.
- Also removed from the shipping binary: the `PANO_STORE_FOLDER` environment
  hook (now Debug-only like the other `PANO_*` flags).

The Release binary now links exactly `AXIsProcessTrusted`,
`CGEventCreateKeyboardEvent` and `CGEventPost`, the same set as Paste.

**Cost:** one manual step (+ or drag) the system used to do for the user.

**If this is rejected too:** the App Review Board appeal in
`ops/appstore/2.4.5-appeal.md` is held in reserve (one appeal per submission),
now with the argument that Pano behaves exactly like the approved apps.
