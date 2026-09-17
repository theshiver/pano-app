# Contributing to Pano

Thanks for taking a look. A few things will save us both time.

## Before you open a pull request

Read the scope boundaries in [CLAUDE.md](CLAUDE.md). Some things are deliberate
permanent decisions rather than missing features:

- No sync, no cloud, no account
- No network access of any kind — the app ships without the network entitlement
- No telemetry
- No paid tier
- macOS only

A pull request adding any of those will be declined, however well written.
If you think one of those decisions is wrong, open an issue and argue the case
before writing code.

## Good first contributions

- A new transform for the transform bar, with a unit test using a real-world input
- Localisation into another language
- Accessibility fixes — VoiceOver labels, focus order, contrast
- Syntax highlighting for a language we do not cover yet
- Importers from other clipboard managers

## Ground rules

- Swift 6, strict concurrency, `swift-format` clean. CI enforces it.
- Code, comments and commit messages in English. UI strings localised.
- Conventional commits: `feat:`, `fix:`, `refactor:`, `docs:`, `test:`, `chore:`.
- One logical change per pull request. Keep diffs focused; don't reformat files
  you aren't otherwise touching.
- New behaviour comes with a test.
- No new third-party dependency without an ADR in `docs/adr/` explaining why the
  standard library or GRDB is not enough.

## Reporting a bug

Include your macOS version, the Pano version, what you copied, and what you
expected. If it involves permissions, say which of the two prompts you granted.

Please do not paste real secrets into an issue — that is the one category of bug
report where a redacted description beats a reproduction.
