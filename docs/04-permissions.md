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
Permission:   Accessibility (System Settings → Privacy & Security → Device Control and Data Access on macOS 27)
Check:        AXIsProcessTrusted()
Prompt:       NONE. Pano never asks macOS; the user adds Pano to the list themselves
Deep link:    x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility
```

**Changed 2026-09-25, after the second 2.4.5 rejection** (`adr/0003`, second
addendum). On macOS 26/27, `AXIsProcessTrustedWithOptions(...prompt: true)`
does not show a dialog; the system dialog *"Pano would like to control this Mac
and access your data"* appears only when the app **posts an event** without the
grant, and macOS adds the app to the list (unchecked) at that moment. Pano used
to post a throwaway event on purpose to get that dialog. It no longer does. The
cost is that macOS does not list Pano by itself: the user clicks + or drags
Pano.app in. That is exactly how every Mac App Store clipboard manager we
checked behaves (Recopy, Clipboard AI, Paste; see the addendum).

Sequence:

1. Write the chosen item to `NSPasteboard.general` (whitelisted types, file URLs
   as separate items, see `adr/0003`).
2. Hide the panel so the previous app regains key focus.
3. If auto-paste is on **and** `AXIsProcessTrusted()` is true, post ⌘V key-down
   and key-up via `CGEvent` on the session event tap. Otherwise post nothing and
   show the hint card.

Nothing is restored afterwards. The item is now the clipboard; the capture loop
sees the change and moves it to the top of history.

Measured: `CGEvent.post` returns in 1–17 ms.

### Auto-paste is opt-in and never requested

Settings → General → Panel → **Paste automatically**, `Preferences.autoPaste`,
**default off**:

- Off (the default) → `PasteService.paste(_:auto:)` writes the pasteboard and
  returns. No event is posted. The preview footer says `⏎ copy … then ⌘V in
  your app` instead of `⏎ paste`.
- On but not trusted → still no event. Settings shows three steps and two
  buttons: *Open System Settings* (deep link) and *Show Pano in Finder*
  (`activateFileViewerSelecting`, so the user can drag Pano into the list).
- On and trusted → ⌘V is posted.

Invariants, all load-bearing for review:

1. **No event is ever posted before the permission is granted.** The only
   `CGEvent.post` in the codebase is in `PasteService.postCommandV()`, and its
   only caller sits behind `guard auto, AXIsProcessTrusted()`. There is no
   prompt trigger; do not add one, and do not add `CGRequestPostEventAccess`
   (its header says "potentially prompting").
2. **Nothing asks macOS for anything.** Turning the setting on, the hint card's
   action and the Settings buttons only record the choice and open panes the
   user then acts in.
3. **Onboarding does not mention auto-paste.** It is shown once per install
   (`Preferences.hasSeenOnboarding`), teaches ⌘⇧V → ⏎ → ⌘V, gives the heads-up
   about the pasteboard prompt, and has one button. The first rejection's
   screenshot was an onboarding permission row.
4. **An ⏎ that does not reach the other app must say so.** `PasteService.paste`
   returns whether the keystroke went out; `false` makes `PasteHintController`
   show a card saying the clip is on the clipboard, with the offer to turn
   auto-paste on (which opens Pano's Settings at the steps above). The card
   stops appearing once the user answers "Don't remind me"
   (`Preferences.autoPasteHintDismissed`).

Never block launch, onboarding or any other feature on this permission.

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
any kind. No Input Monitoring — the global hotkey uses
Carbon's `RegisterEventHotKey`, which works inside the sandbox and raises no
prompt at all.

The entitlements file is a product statement. If a task appears to require
adding one, stop and ask.
