# ADR 0008 — No auto-paste on the Mac App Store

**Status:** accepted · 2026-09-30 · supersedes `0003`

## Context

Auto-paste (⏎ in the panel posts ⌘V into the app the user came from) needs the
permission System Settings lists under Accessibility (Device Control and Data
Access on macOS 27). App Review rejected Pano four times under guideline 2.4.5:

| Build | Date | What had changed | Result |
|---|---|---|---|
| 1.0 (3) | 2026-09-21 | Asked for the permission on first run | Rejected |
| 1.0 (6) | 2026-09-25 | Opt-in, off by default | Rejected, same template |
| 1.0 (7) | 2026-09-29 | Never requested the permission, never posted untrusted; user added Pano by hand | Rejected: *"Specifically, the app uses Accessibility features for auto-paste."* |

The last rejection names the feature itself. How the permission is requested
does not matter.

Other clipboard managers on the Mac App Store use the identical mechanism
(Recopy, Clipboard AI, Pastebot 3, Paste; verified from their binaries, see
`0003`'s second addendum). No Aug/Sep 2026 report shows a *new* app getting it
approved. Fingertips (a snippet app) was rejected for the same `CGEvent.post` ⌘V
on 2026-08-20, lost its App Review Board appeal on 2026-08-27, removed the
feature and was approved a week later.

## Decision

Pano does not paste into other apps. ⏎ puts the clip on the pasteboard and the
user presses ⌘V, which is also Maccy's default (`pasteByDefault = false`).

- `PasteService` only writes the pasteboard. There is no `CGEvent` posting, no
  `AXIsProcessTrusted`, no deep link to the permission pane. The Release binary
  links none of the Accessibility or event APIs.
- The preview footer says `⏎ copy … then ⌘V in your app`, and a card after ⏎
  says the same until the user answers "Don't remind me".
- Onboarding stays, as an introduction only. Pano is a menu-bar-only app
  (`LSUIElement`); without it a first launch shows nothing and never teaches ⌘⇧V.
- The App Store listing and the site are repositioned around finding,
  transforming and privacy, not around pasting.

## Consequences

- One extra keystroke compared with the apps above.
- The App Review Board appeal drafted in `ops/appstore/2.4.5-appeal.md` is not
  sent.
- The removed implementation is in git at `993c75f` (and `0003`).

## Revisit when

Users ask for auto-paste in reviews or issues. The plan then (Can, 2026-09-30)
is to leave the Mac App Store and ship the auto-paste build as a notarized DMG
and a Homebrew cask, which also reopens the "Mac App Store only" line in
`CLAUDE.md`. Not before there is demand: a second channel is ongoing work for a
part-time project (Developer ID signing, notarization, an update mechanism).
