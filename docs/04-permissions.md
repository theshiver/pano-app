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

Every way of pressing ⌘V on the user's behalf needs the user to trust the app
for **Accessibility**. That includes Apple Events → System Events, whose
`keystroke` command checks the sender's Accessibility trust and fails with
`1002` otherwise. There is no permission-free path; the question is only how
many dialogs and entitlements sit on top of that one grant.

| Technique | Entitlements | Dialogs | Verdict |
|---|---|---|---|
| `CGEvent.post` | `app-sandbox` only | Accessibility | **What Pano uses.** What Maccy ships on the Mac App Store |
| Apple Events → System Events | `app-sandbox` + `temporary-exception.apple-events` + `automation.apple-events` + usage string | Automation, then Accessibility | Strictly worse. Verified in week 0, see `adr/0003` |
| Accessibility API (`AXUIElement…`) | — | — | Not needed for pasting; not used |

### The chosen path

```
Entitlements: com.apple.security.app-sandbox
Permission:   Accessibility (System Settings → Privacy & Security → Device Control and Data Access)
Check:        AXIsProcessTrusted()
Prompt:       raised by posting the first CGEvent, NOT by AXIsProcessTrustedWithOptions
Deep link:    x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility
```

On macOS 26/27, `AXIsProcessTrustedWithOptions(...prompt: true)` does **not**
show a dialog — `tccd` logs *"kTCCServiceAccessibility does not allow
prompting"*. The prompt *"Pano would like to control this Mac and access your
data"* (with *Open System Settings*) appears the first time the app **posts an
event**, and macOS adds Pano to the list (unchecked) at that moment. So
onboarding triggers the prompt by attempting a paste, then polls
`AXIsProcessTrusted()` while the user flips the one switch. The deep link opens
the right pane (verified on macOS 27). The pane is now labelled *Device Control
and Data Access*, not *Accessibility*.

Sequence:

1. Write the chosen item to `NSPasteboard.general` (whitelisted types, file URLs
   as separate items, see `adr/0003`).
2. Hide the panel so the previous app regains key focus.
3. If auto-paste is on and `AXIsProcessTrusted()` is true, post ⌘V key-down and
   key-up via `CGEvent` on the session event tap. Otherwise show a brief hint to
   press ⌘V and stop.

Nothing is restored afterwards. The item is now the clipboard; the capture loop
sees the change and moves it to the top of history.

Measured: `CGEvent.post` returns in 1–17 ms.

### Auto-paste must be optional

Build it as a setting, default on, that degrades:

- Permission not granted, or the setting is off → put the item on the pasteboard,
  hide the panel, show a brief hint to press ⌘V. The app is still useful.
- Never block launch, onboarding or any other feature on this permission.

This is not a fallback plan, it is the correct design. It also means a review
rejection on auto-paste can be answered by shipping with the setting off rather
than by pulling the app.

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
Bluetooth. Accessibility only for auto-paste, and only if the user opts in. No
Apple Events, no temporary exceptions of any kind. No Input Monitoring — the global hotkey uses
Carbon's `RegisterEventHotKey`, which works inside the sandbox and raises no
prompt at all.

The entitlements file is a product statement. If a task appears to require
adding one, stop and ask.
