# Week 0 — the spike

Four days. Nothing here is production code; all of it is throwaway except the
repo skeleton. The point is to answer questions before they can cost a week.

Work through it in order. Each task states what "done" looks like.

## Day 1 — auto-paste in the sandbox — **done 2026-09-17**

The plan below was executed and both of its assumptions failed; `adr/0003` has
the findings and the replacement design (`CGEvent` + Accessibility, no restore
loop). Kept here so the failure is visible. Spike: `../../spike/SpikePaste`.

Original tasks: sandboxed app, `automation.apple-events`, ⌘V via System Events,
snapshot → paste → restore, measure the restore delay. What actually happened:
`-600` from `appleeventsd` until a temporary exception was added, then a
second (Accessibility) dialog for `keystroke`, then a restore loop that broke
Finder file pastes. Maccy's source showed the simpler path in ten minutes.

## Day 2 — the pasteboard access permission — **blocked 2026-09-17**

Not walkable on macOS 27: no alert, no Settings section, `.alwaysAllow` from
the first query; the developer-preview flag hangs `accessBehavior`. Details
and the consequences for onboarding in `04-permissions.md`. Needs a macOS 15.x
or 26 machine; parked until one is available.


1. In the spike, read `NSPasteboard.general.accessBehavior` and log it. Expect
   `.default` on a machine that has never seen the app.
2. Read the pasteboard programmatically. The alert should appear once.
3. Log `accessBehavior` again — expect `.ask`.
4. Open System Settings → Privacy & Security → **Paste from Other Apps**. Confirm
   the app is listed. Set it to Always Allow.
5. Log once more — expect `.alwaysAllow`. Read again and confirm no alert.
6. Try the `detect` APIs on `NSPasteboard` while the state is `.ask`, and check
   what they report without raising an alert.

**Done when:** you have personally walked the full path a user will walk, and you
know exactly what each state looks like. This is what week 3's onboarding screen
is designed against.

## Day 3 — name and accounts

1. Registrar: check the domain you want for the landing page.
2. App Store Connect → My Apps → **+** → New App. Reserve the name
   **`Pano: Clipboard Manager`**. Reserving does not commit you to shipping, and
   if you do not reserve it, someone else can take it.
3. Bundle ID: register `com.cancetin.pano` in the developer portal. No
   capabilities.
4. Trademark search: TÜRKPATENT and USPTO, class 9, software. Not legal advice;
   it is a cheap check against an expensive surprise.
5. GitHub: create `pano-app` per `../../ops/github-setup.md`.

**Done when:** the name is locked in App Store Connect and the repo exists.

## Day 4 — the skeleton — **done 2026-09-17** (CI pending first push)

Built with `xcodegen` from `project.yml`; the generated project is committed.
Each package has one passing smoke test rather than a failing one, because a
red CI on day one teaches nothing. Bundle ID `com.cancetin.pano`, team
`S2RH54MMT3`, entitlement `app-sandbox` only.

Now inside this repo.

1. `Pano.xcodeproj`, macOS 15.4 deployment target, Swift 6, strict concurrency on.
2. Four local SPM packages: `PanoCore`, `PanoStore`, `PanoTransforms`, `PanoUI`,
   with the dependency directions in `02-architecture.md`.
3. GRDB added to `PanoStore` only.
4. A failing test in each package, so CI has something to run.
5. `swift-format` config at the root.
6. Push, confirm the CI workflow goes green.
7. Copy the working entitlement and Info.plist keys from the spike into the real
   target, and verify the spike's paste path still works from inside `Pano`.

**Done when:** `main` builds, CI is green, and the app — which does nothing yet —
can already paste a hardcoded string into TextEdit.

## What week 0 is not

Not the capture loop. Not the schema. Not the panel. Not a single line of UI. If
you find yourself designing the row view on day 2, stop: weeks 1–2 are for that,
and the spike's only job is to remove uncertainty.

## Record the answers

When the four days are done, write the results into the relevant ADR. Day 1 is
already in `docs/adr/0003`. Anything that behaves differently from what
`04-permissions.md` predicts goes there too. Future-you and Claude Code will both
trust that file, so no claim without a source.
