# Pano

A clipboard manager for macOS that is free, open source, and never sends your
data anywhere.

macOS already remembers what you copied — in Spotlight, for half a day, with no
pinning, no per-app exclusions, and rich text stripped out. Every good
third-party alternative is a subscription. Pano is the other option: the whole
app, free, with the source in this repo.

**Status: pre-release.** Nothing is shipping yet. See [the roadmap](docs/06-roadmap.md).

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

No sync. No cloud. No account. No telemetry. **The app ships without the network
entitlement**, so this is verifiable rather than promised. No subscription, no
paid tier, no feature gates.

If you need your clipboard on your phone, Pano is not the tool.

## Privacy

Everything lives in one SQLite file in your Application Support folder. Anything
a password manager marks as concealed never enters the database. API keys, JWTs,
card numbers and IBANs are detected, masked in the list, and expire on the short
retention rule.

Pano needs two permissions, both asked for by macOS and both revocable:

- **Paste from Other Apps** — to read the clipboard at all
- **Accessibility** — to press ⌘V for you in the app you were in.
  Decline it and Pano still works; you press ⌘V yourself.

## Install

Not released yet. It will be available on the Mac App Store (free), as a
notarized DMG, and via `brew install --cask pano`.

## Build

Requires Xcode 16 or later and macOS 15.4 or later.

```
git clone https://github.com/<owner>/pano-app.git
cd pano-app
open Pano.xcodeproj
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). The scope boundaries in
[CLAUDE.md](CLAUDE.md) apply to human contributors too — please read them before
opening a pull request that adds sync, a network call, or AI.

## Licence

MIT. See [LICENSE](LICENSE). The Pano name and icon are excluded.
