# Pano

A clipboard manager for macOS that is free, open source, and never sends your
data anywhere. Website: [pano-app.com](https://pano-app.com)

macOS already remembers what you copied — in Spotlight, for half a day, with no
pinning, no per-app exclusions, and rich text stripped out. Every good
third-party alternative is a subscription. Pano is the other option: the whole
app, free, with the source in this repo.

**Now available:** Free and open source (MIT). Install via [Direct DMG / Homebrew](https://github.com/theshiver/pano-app/releases/latest) (includes optional Auto-Paste) or the [Mac App Store](https://apps.apple.com/app/id6812981549).

## What it does

- Unlimited history with instant search, backed by SQLite FTS5
- A keyboard-first panel that opens next to your cursor and pastes back into the
  app you were in
- Live preview beside the list — code with syntax highlighting, colours as
  swatches, images with searchable OCR text
- A transform bar: type `json`, `b64`, `jwt`, `slug`, `url` or `clean` and the
  preview converts as you type; press return to paste the converted value
- Colour conversion: copy a hex, paste it as `rgb()`, `hsl()`, a SwiftUI `Color`
  or a Tailwind class
- A source-app rail, because people remember *what they were doing* when they
  copied something, not when
- Pinboards, pinning, plain-text paste, per-app exclusions, numbered quick paste
- Rule-based retention: things that look sensitive expire in an hour, everything
  else in thirty days

## What it deliberately does not do

No sync. No cloud. No account. No telemetry. **Neither build ships with a network entitlement**, so this is verifiable rather than promised. No subscription, no paid tier, no feature gates.

If you need your clipboard on your phone, Pano is not the tool.

## Privacy

Everything lives in one SQLite file in your Application Support folder. Anything a password manager marks as concealed never enters the database. API keys, JWTs, card numbers and IBANs are detected, masked in the list, and expire on the short retention rule.

Permissions requested by macOS (all revocable):

- **Paste from Other Apps** — to read the clipboard at all
- **Accessibility (Direct DMG / Homebrew build only, optional)** — to press ⌘V for you in the app you came from when Auto-Paste is enabled. Decline it and Pano still works; you press ⌘V yourself. See the [Auto-Paste setup guide](https://pano-app.com/auto-paste-setup/). The Mac App Store build is strictly sandboxed and contains zero Accessibility or synthetic-event APIs.

## Install

Choose the free build that fits your workflow:

- **Direct DMG / Homebrew (includes optional Auto-Paste):** Download `Pano-1.1.dmg` from [GitHub Releases](https://github.com/theshiver/pano-app/releases/latest), or install via Homebrew:
  ```bash
  brew install --cask theshiver/tap/pano
  ```
  See the [Auto-Paste & Accessibility setup guide](https://pano-app.com/auto-paste-setup/) for macOS permission steps.
- **Mac App Store (strictly sandboxed, copy-only):** Install from the [Mac App Store](https://apps.apple.com/app/id6812981549).

## Build

Requires Xcode 16 or later and macOS 15.4 or later.

```bash
git clone https://github.com/theshiver/pano-app.git
cd pano-app
open Pano.xcodeproj
```

Select the `PanoDirect` scheme for the non-sandboxed build with Auto-Paste, or `Pano` for the strictly sandboxed Mac App Store build.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). The scope boundaries in
[CLAUDE.md](CLAUDE.md) apply to human contributors too — please read them before
opening a pull request that adds sync, a network call, or AI.

## Licence

MIT. See [LICENSE](LICENSE). The Pano name and icon are excluded.
