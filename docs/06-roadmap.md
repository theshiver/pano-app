# Roadmap

Eight weeks, part-time, with Claude Code. The sequence is not arbitrary: each
week leans on the uncertainty the previous one closed.

**The most important date is week 4, not week 8.** That is the day the app
replaces Maccy in daily use. After that every line goes into a tool used every
day rather than into a void, and the odds of the project finishing roughly
double. Protect that date ahead of any feature.

## Week 0 — four days — hunt the unknowns

Everything on your own machine. See `07-week-0.md` for the step-by-step.

- Sandboxed empty app: grant Accessibility, post ⌘V with `CGEvent`, confirm it
  lands. Done 2026-09-17, see `adr/0003` for what was tried first and why it lost
- Round-trip the stored type set (rich text, pixels, one and several files) into
  TextEdit and Finder. Done 2026-09-17, all pass
- Trigger the pasteboard access alert, confirm the app appears in System
  Settings, confirm `.alwaysAllow` silences it. Blocked on macOS 27 (no alert
  exists there), parked; see `04-permissions.md`
- Lock the name: reserve `Pano: Clipboard Manager` in App Store Connect,
  registrar, trademark search
- Repo skeleton, SPM packages, CI, MIT licence

**Exit:** auto-paste confirmed working in the sandbox with your own eyes, the
permission flow experienced end to end, the name reserved.

## Weeks 1–2 — the engine

- `changeCount` polling loop, type parsing: text, rich text, image, file, URL, colour
- GRDB schema, FTS5 index, duplicate merging, retention infrastructure
- Source app detection
- Privacy layer: concealed types, exclusion list, sensitive-pattern detection
- Unit tests, including the 100,000-row search benchmark

**Exit:** no UI, but the data is captured correctly and search is under 10 ms at
100,000 rows.

## Weeks 3–4 — the panel ★

- Three-zone `NSPanel`, non-activating, positioned near the cursor
- Keyboard navigation, global hotkey, numbered quick paste
- Pinning, plain-text paste, pause, clear history
- Auto-paste via `CGEvent`, plus the manual ⌘V fallback when Accessibility is absent
- Permission onboarding: pasteboard access and Accessibility, explained separately
- Settings screen: panel position (done), retention windows (done), launch-at-login
  (done, verify from an installed build — SMAppService may not register from a dev
  DerivedData path). Still to add: a hotkey recorder and exclusion-list management.

**Exit:** you delete Maccy.

## Weeks 5–6 — character

- Transform bar: json, b64, jwt, slug, url, markdown, clean
- Colour conversion: hex, rgb, hsl, SwiftUI `Color`, Tailwind
- Syntax highlighting with language detection (shipped hand-rolled; replace with a library — Highlightr — for consistency, see adr/0006, needs adr/0007)
- Vision OCR and image text search
- Search syntax: `app:`, `type:`, `>7d`, `pinned:`

**Exit:** the app is no longer a prettier Maccy. It is a different thing.

## Week 7 — organisation

- Source-app rail and filtering
- Pinboards: name, colour, icon, drag to add
- Rule-based retention and masking, surfaced in Settings
- Drag out of the panel
- Status bar
- A pass across light, dark and increased-contrast

**Exit:** the app still feels roomy with thousands of items in it.

## Week 8 — ship

- Turkish and English localisation
- Accessibility pass: VoiceOver, keyboard focus, contrast
- Empty states, error states, first-run flow
- Landing page, README, contributing guide, tip link
- App Store submission, notarized DMG, Homebrew cask

**Exit:** a stranger can install it and use it without asking anyone anything.

## After v1

**v1.1** — image quick actions · multi-select and paste-joined · import from
Maccy · frequency hint · drag into the panel.

**v2** — rule-based smart pinboards · Shortcuts actions · CLI · snippets · AI and
semantic search, last.

None of it leaks into v1.

## The risk register, short version

| Risk | Mitigation |
|---|---|
| The project is abandoned | The week 4 milestone. Everything else is secondary |
| App Review rejects auto-paste | Same mechanism and permission as Maccy, which is on the store; the feature is switchable, so a rejection costs a setting, not the app |
| The user is lost in permission onboarding | Design that screen twice; use `detect` so the app is not blind before consent. The pasteboard alert has never been observed by this project (macOS 27 does not show it); walk it on a 15.x/26 machine before week 3's onboarding copy is final |
| Scope creep | The badges in `01-product.md` are binding |
| Performance at scale | Week 2's exit criterion is a benchmark, written before the UI exists |
| "The built-in Tahoe history is enough" | The App Store description's first paragraph answers it |
