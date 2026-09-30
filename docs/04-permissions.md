# Permissions

Read this before touching capture or paste. Two separate mechanisms get confused
constantly; they have different APIs, different prompts and different failure modes.

## Problem 1 — reading the pasteboard

macOS 15.4 added `NSPasteboard.AccessBehavior` and a pasteboard-access alert.
What the SDK header (`NSPasteboard.h`, macOS 27 SDK) says:

- An app that has never triggered the alert reports `.default` and is not shown
  in System Settings.
- The first programmatic read raises one alert and flips the state to `.ask`.
- From then on the app is listed in System Settings, where the user can choose
  `.ask`, `.alwaysAllow` or `.alwaysDeny`.
- Access that is *user originated and paste related* is always allowed and never
  alerts, in every state.

What is **not** in the header and was wrong in the first version of this file:
on macOS 15.4–15.5 the alert only exists behind a per-app developer-preview
default (`EnablePasteboardPrivacyDeveloperPreview`); Apple's April 2025 AppKit
notes said it would ship for real in macOS 26. There is no MDM control for it
(Apple forum thread 794560, DTS reply, 2025).

**Week 0 observation on macOS 27.0 (2026-09-17), unverified elsewhere:**

- Without the flag: a fresh app reports `.alwaysAllow` on first query, reads
  never alert, `tccd` never receives a `kTCCServicePasteboard` request (from
  any app on the machine), and System Settings has no "Paste from Other Apps"
  section. `tccutil reset Pasteboard <bundle id>` succeeds and changes nothing.
- With the flag: reading `accessBehavior` blocks the main thread forever
  (`HIRunLoopSemaphore wait`, no TCC traffic).
- So the full `.default → alert → .ask → Settings → .alwaysAllow` walk could
  not be done. Nobody on this project has seen the alert. Whether macOS 26
  shipped it, and whether 27 removed it, is unknown; do not write copy that
  quotes the alert text.

**Implications:** the code handles all four enum values because the contract
says so, and the UI is driven only by the enum, never by assumptions about
which dialog the user saw. Until the walk is done on a macOS 15.x or 26
machine, the onboarding copy stays generic ("if macOS asks about clipboard
access, allow it; here is where to change it later"). Read `accessBehavior`
off the main thread, or guard it with a timeout, because it is a synchronous
call to the pasteboard server.

**Implementation:**

- Read `NSPasteboard.general.accessBehavior` on launch.
- `.default` → show the onboarding screen and explain what the alert will be
  before triggering it. Never let the first alert arrive unexplained.
- `.ask` → the user has seen the alert but not granted persistent access. Show a
  persistent, dismissible banner explaining the Settings path.
- `.alwaysAllow` → normal operation.
- `.alwaysDeny` → the app is functionally off. Say so plainly and offer the path
  back rather than silently showing an empty list.

Use the `detect` APIs on `NSPasteboard` and `NSPasteboardItem` in the
non-granted states. They report which *kinds* of data are on the pasteboard
without reading the contents and without raising the alert, so the app can say
"there is an image on your clipboard, grant access to keep it" instead of
looking broken.

## Problem 2 — pasting back

**Pano does not paste into other apps** (`adr/0008`, 2026-09-30). ⏎ writes the
chosen clip to `NSPasteboard.general` and the user presses ⌘V.

Every way of pressing ⌘V on the user's behalf needs the permission System
Settings lists under Accessibility, and App Review rejected Pano four times for
using it for auto-paste, the last time naming the feature itself. The history,
what was measured and what other Mac App Store apps ship is in `adr/0003` and
`adr/0008`.

Rules:

1. **No event posting and no Accessibility API in this target.** No `CGEvent`
   post, no `AXIsProcessTrusted`, no `CGRequestPostEventAccess`, no deep link to
   that pane. The Release binary links none of them; keep it that way.
2. **The write is complete.** Every stored type in stored order, file URLs as
   separate items (`adr/0003`, "What is stored per item"). No restore.
3. **⏎ must visibly do something.** The preview footer says `then ⌘V in your
   app`; `PasteHintController` shows a card after ⏎ until the user answers
   "Don't remind me" (`Preferences.copyHintDismissed`).

## Verifying before building

The technical half was answered in week 0: sandboxed build, Accessibility
granted, `CGEvent.post`, paste lands. The spike and its log are in
`spike/SpikePaste` next to this repo.

The policy half cannot be fully answered before submission, but a Developer
Technical Support incident is the right instrument if doubt remains — the
developer account includes two free ones a year. DTS speaks to technical
compatibility and explicitly not on behalf of App Review.

## Permissions Pano does not request

No network entitlement. No microphone, camera, location, contacts, calendar,
Bluetooth. Accessibility only for auto-paste, and only if the user opts in. The
only file entitlement is `files.user-selected.read-only` (the app-picker and
files the user explicitly copies); no Apple Events, no temporary exceptions of
any kind. No Accessibility and no Input Monitoring — the global hotkey uses
Carbon's `RegisterEventHotKey`, which works inside the sandbox and raises no
prompt at all.

The entitlements file is a product statement. If a task appears to require
adding one, stop and ask.
