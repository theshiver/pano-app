# Pano — working agreement for Claude Code

Read this file completely before doing anything in this repo.

## What Pano is

A free, open-source clipboard manager for macOS. **Local only**: no sync, no cloud,
no account, no telemetry, no network code at all. Distributed free on the Mac App
Store only; no DMG, no Homebrew cask, no binaries on GitHub. MIT licensed.
The repo stays private until after the App Store launch, so nothing user-facing
(App Store text, site, review notes) may claim "open source" or link the repo yet.

One-line promise: *as fast as Maccy, as good-looking as Paste, completely free, and
the data never leaves the Mac.*

## Hard scope boundaries

These are decisions, not preferences. Do not re-open them, do not "helpfully" add
them, and push back if asked to slip one in mid-task.

**Never in this codebase:**
- iOS, iPadOS, visionOS. macOS only.
- iCloud, CloudKit, any sync, any server, any account system.
- Any outbound network request. The app ships with **no** network entitlement.
  This is a product promise, not an implementation detail. That includes
  "just fetching the page title for a copied URL" — explicitly rejected.
- Telemetry, crash reporting SaaS, analytics.
- Team/sharing features.
- A text expander.
- Paid tiers or feature gates. Everything is free.

**Not in v1** (see `docs/06-roadmap.md` for what ships when):
- Snippets / templates
- Shortcuts actions, CLI, MCP server
- AI or semantic search — and it must not appear in the app name, the App Store
  listing, or the marketing copy either
- Rule-based smart pinboards (regex)
- Drag *into* the panel (drag *out* is v1)

## Stack

- Swift 6, strict concurrency. macOS 15.4 minimum.
- SwiftUI for views, AppKit where SwiftUI cannot reach (the panel window is one).
- GRDB + SQLite with an FTS5 index. **Not** SwiftData — see `docs/adr/0002`.
- Vision framework for OCR.
- Swift Package Manager, local packages inside the repo.
- Third-party dependencies: GRDB, and Highlightr in `PanoUI` (`docs/adr/0007`).
  Anything else needs an ADR justifying it.

## Repo layout

```
project.yml            source of truth for the Xcode project; `xcodegen generate` after editing
Pano.xcodeproj         generated, committed so CI and contributors need no extra tool
Pano/                  app target: entry point, app delegate, wiring
Packages/
  PanoCore/            models, pasteboard capture, privacy rules, paste service
  PanoStore/           GRDB schema, queries, FTS, retention
  PanoTransforms/      json/b64/jwt/slug/url/markdown/clean/colour
  PanoUI/              panel, rows, preview, settings views
  */Tests/             each package's tests live inside it
docs/                  everything below
.github/workflows/     CI
```

Targets, entitlements and build settings are edited in `project.yml`, never in
Xcode's UI: xcodegen overwrites `Pano/Pano.entitlements` from the `entitlements`
block on every generate. Adding an entitlement is a product decision — stop and
ask (see the permissions rules below).

## Where to find what

| Question | File |
|---|---|
| What are we building and why | `docs/01-product.md` |
| Module boundaries, data flow | `docs/02-architecture.md` |
| Database schema, FTS, retention | `docs/03-data-model.md` |
| **Permissions — read before touching capture or paste** | `docs/04-permissions.md` |
| Visual spec: sizes, colours, states | `docs/05-design.md` |
| What ships in which week | `docs/06-roadmap.md` |
| The very first tasks | `docs/07-week-0.md` |
| Why a decision was made | `docs/adr/` |

## Non-negotiable technical constraints

Full detail in `docs/04-permissions.md`. The short version, because getting these
wrong wastes days:

1. **The panel must be an `NSPanel` with `.nonactivatingPanel`.** If the panel
   takes key focus, the previously focused app loses it and paste-back cannot
   work. Do not build the main panel as a plain SwiftUI `Window` or `WindowGroup`.

2. **Auto-paste posts ⌘V with `CGEvent` and needs the user's Accessibility
   grant.** No Apple Events, no `temporary-exception` entitlements, no System
   Events scripting. The entitlements file contains exactly `app-sandbox` and
   `files.user-selected.read-only` (the latter for the Settings app-picker and
   files the user explicitly copies) — nothing else. This is essentially what
   Maccy ships on the Mac App Store; the Apple Events route was tried in week 0
   and needs Accessibility anyway plus two more entitlements and a second dialog.
   Details in `docs/adr/0003`.

3. **Auto-paste is opt-in (off by default) and degrades gracefully.** Off by
   default since the App Store 2.4.5 review. Without it, or without the
   Accessibility grant, the app puts the item on the pasteboard and tells the
   user to press ⌘V. Auto-paste is never allowed to be a launch blocker.
   **Never post an event before `AXIsProcessTrusted()` is true, and never ask
   macOS to prompt** (no throwaway events, no `CGRequestPostEventAccess`). The
   user adds Pano to the list themselves. Rejected twice without this rule; see
   `docs/adr/0003`, second addendum.

4. **Reading the pasteboard triggers a system alert once** (macOS 15.4+,
   `NSPasteboard.AccessBehavior`). The user then has to switch the app to
   "Always Allow" in System Settings themselves — Apple deliberately does not
   allow a link in that alert. Onboarding has to walk them there. Use the
   `detect` APIs so the app is not completely blind before permission is granted.

5. **There is no pasteboard restore.** The item the user picks becomes the
   clipboard, as in every other clipboard manager. Write back every stored type
   in stored order, file URLs as separate items; writing only `.string` silently
   turns rich text and files into plain text.

6. **Honour `org.nspasteboard.ConcealedType` and `org.nspasteboard.TransientType`.**
   Anything a password manager copies must never reach the database.

## Coding conventions

- Swift API Design Guidelines. `swift-format` config is in the repo; CI enforces it.
- Code, comments, commit messages, docs and issues: **English**.
- UI strings: localised, Turkish and English, no hardcoded user-facing text.
- One type per file, file named after the type.
- Prefer `struct` and value semantics. `actor` for the capture loop and the store.
- No force unwrapping, tests included (CI's swift-format enforces `NeverForceUnwrap`
  everywhere). No `try!`.
- Tests live beside the package they test; every transform gets a unit test with
  a real-world input, not a synthetic one.
- Accessibility is not a phase-8 chore: every control gets a label as it is written.

## How to work here

This project is being built part-time by one person. Velocity comes from not
doing extra work, not from doing work faster.

- **Ask when it matters.** If intent, architecture or a requirement is genuinely
  unclear, or the change is hard to reverse, ask first. For clear, low-risk work,
  state your assumption and proceed.
- **Question the request.** If a request seems off, under-specified, or aimed at
  the wrong problem, say so and confirm before executing it literally.
- **Simplest thing that works.** No abstraction, protocol or generic that is not
  needed by code that exists today.
- **Stay in scope.** Only touch what the task is about. Note unrelated problems at
  the end instead of fixing them.
- **Flag uncertainty explicitly** before stating a fact, number or API behaviour
  you are not sure about. Never fill a gap with a plausible guess — especially
  about macOS APIs and entitlements, where guessing costs a day.
- **No yes-man.** If a proposed approach is feasible but adds debt or is
  over-engineered, say so and offer the simpler alternative.
- **Before anything destructive** (deleting files, dropping tables, rewriting a
  module, removing a dependency): list what is affected and get explicit
  confirmation in the current message.
- **After a coding task**, end with: files changed (one line each), files
  deliberately not touched, follow-up needed.

Responses to Can: Turkish for discussion, English for code and technical writing.
Short, direct, no filler openers, no closing summary that repeats what was said.

## Commits and branches

- Conventional commits: `feat:`, `fix:`, `refactor:`, `docs:`, `test:`, `chore:`.
- One logical change per commit. No "wip" on `main`.
- Branch per feature: `feat/transform-bar`, `fix/panel-focus`.
- Never commit to `main` directly once the repo is public.
- Never commit: `*.xcuserdatad`, provisioning profiles, signing certificates,
  API keys, the user's own clipboard database.

## Definition of done for a week

A week in `docs/06-roadmap.md` is done when its exit criterion is true, the tests
pass, CI is green, and the app still launches and behaves at the previous week's
level. Not before.
