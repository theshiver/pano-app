# Changelog

All notable changes to Pano are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses
[semantic versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0] - 2026-09-22

First release.

### Added

- Unlimited clipboard history in a local SQLite file, with instant full-text
  search and filters (`type:`, `app:`, `pinned:`, age such as `7d`).
- A keyboard-first panel on ⌘⇧V: type to search, ⏎ to copy a clip, ⇧⏎ for the
  plain-text version, ⌘1–9 for quick picks, ⌘P to pin, ⌘⌫ to delete.
- Transforms that run as you type: `json`, `b64`, `jwt`, `slug`, `url`, `clean`,
  `markdown`, and colour conversions including a Tailwind match.
- On-device OCR, so text inside copied images is searchable.
- A rail of source apps, pinboards for clips worth keeping, and drag-out.
- Secret detection (API keys, JWTs, card numbers, IBANs) with optional masking
  and a shorter retention window; anything marked concealed is never recorded.
- Per-app exclusions, retention rules, a recordable global shortcut, syntax
  themes, and launch at login.

### Notes

- Everything stays on the Mac. The app ships without the network entitlement
  and collects nothing.
- ⏎ copies the clip and you press ⌘V. Pano does not paste into other apps for
  you, so it needs no permission beyond clipboard access.
