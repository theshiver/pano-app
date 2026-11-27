# Changelog

All notable changes to Pano are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses
[semantic versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.1] - 2026-11-27

### Added

- Dual distribution: sandboxed Mac App Store build (`Pano`, copy-only) and direct
  DMG / Homebrew Cask target (`PanoDirect`, opt-in Accessibility auto-paste).
- New Tri-Pane app icon and crisp vector template menu bar icon.
- Resizable panel (remembers size), auto-dismiss on click outside, row hover
  highlight, right-click row context menu, and image thumbnails in the list.
- Feature discovery: clickable quick-filter strip (`Code`, `Images · OCR`,
  `Colours`, `Pinned`), optional 3-clip onboarding starter pack, and dismissible
  contextual tips.
- Quick privacy cleanup: Clear Last 15 Minutes / Last Hour from the menu bar,
  separate text vs image retention pickers, secret expiry picker, and Pause
  capture in Settings.
- Gentle Mac App Store review prompt after sustained usage.

### Fixed

- Rich text preview layout jump: bounded LRU preview cache, background neighbor
  prefetch, font size normalization, and HTML background color stripping.
- Automatic retention sweeping (`sweepExpired`) wired at launch, hourly, and on
  Settings changes so expired clips and 1-hour secrets are actually removed.
- Performance: SQLite WAL mode, composite `(is_pinned DESC, last_seen_at DESC)`
  index, search debouncing, cached transform/language/swatch/icon lookups, and
  whitelist-first pasteboard reads.
- Accessibility: StatusBar Settings button is no longer swallowed by VoiceOver,
  and HotKeyRecorderField formats Space, Return, Tab, arrows, and F-keys cleanly.

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
