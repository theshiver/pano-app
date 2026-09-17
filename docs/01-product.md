# Product

## Positioning

> As fast as Maccy, as good-looking as Paste, completely free, and the data never
> leaves the Mac.

Pano is built primarily as a daily tool for its author, and secondarily as an
open-source contribution. It is not a business. That changes what matters: the
risk is not competition, it is the project never being finished. Every decision
below is biased toward shipping something usable in week four.

## The market gap, in one table

Searching the Mac App Store for "clipboard manager" in September 2026 returns
three paid results and nothing that is free, open source and well designed.

| App | Mac App Store price | Open source | Note |
|---|---|---|---|
| Paste | $29.99/year | No | The design benchmark of the category |
| Pastebot 3 | $24.99/year | No | Rewritten July 2026; deep automation; requires macOS 26 |
| Maccy | $9.99 one-off | MIT | Free from maccy.app and Homebrew; the App Store build is sold to fund development. Menu-bar dropdown only |
| Clipaste | not listed | Mac side only | GPL-3.0, so it cannot enter the App Store at all. Its iOS keyboard is closed source and paid |
| macOS Tahoe | built in | — | Clipboard history in Spotlight (⌘Space then ⌘4); 26.1 added retention settings |
| **Pano** | **free** | **MIT** | The empty slot |

## Apple is now a competitor

macOS 26 Tahoe ships clipboard history inside Spotlight. The App Store
description has to answer "why not just use the built-in one" in its first
paragraph. The documented gaps in the built-in history:

- No user-controlled per-app exclusions; apps must opt themselves out
- No pinning; everything expires with the retention setting
- No lock; the history is readable without authentication
- Rich formatting is stripped, and entries over roughly 16,000 characters are dropped
- Two keystrokes to reach, no dedicated global hotkey
- No API, no plugin surface, no per-copy hooks, so no type detection and no
  formatted previews

That list is close to an inverse of Pano's v1 feature set. Not a coincidence:
Apple left the built-in tool at baseline deliberately.

## Who it is for

A developer or designer on a Mac who copies constantly, wants the history
searchable and pretty, and does not want a subscription or their clipboard in
somebody's cloud. Turkish and English UI.

## Feature catalogue

Badges are binding. Nothing marked v1.1 or v2 may be pulled into v1, however
easy it looks on the day.

### Baseline — v1

Without these the app reads as incomplete.

| Feature | Note |
|---|---|
| Unlimited history, instant search | SQLite FTS5 |
| Global hotkey, full keyboard navigation | No function reachable only by mouse |
| Pinning and favourites | |
| Preview pane | The panel's right column |
| Paste as plain text | |
| Per-app exclusion list | Type-aware too: "no images from this app" |
| Password-manager integration | `org.nspasteboard.ConcealedType` |
| Duplicate merging | Move existing row up with a counter, don't insert a new one |
| Type support | Text, rich text, image, file, URL, colour |
| Numbered quick paste | ⌘⇧V then 1–9 |
| Pause and clear history | |
| Permission onboarding | Mandatory; see `04-permissions.md` |

### Competitive parity — v1

| Feature | Note |
|---|---|
| Syntax highlighting | Language detection; 6–7 languages is enough |
| Pinboards | Simple: name, colour, icon |
| Drag out of the panel | Drag *into* the panel is v2 |

### Differentiators — v1

These are the reasons the app exists rather than being a Maccy fork.

| Feature | Note |
|---|---|
| Colour format conversion | hex → rgb → hsl → SwiftUI `Color` → Tailwind class. No competitor does this |
| Text cleanup | Broken line endings, doubled spaces and soft hyphens from PDFs and the web |
| Rule-based retention | Sensitive-looking items expire in an hour, the rest in thirty days |
| Search syntax | `app:xcode`, `type:image`, `>7d`, `pinned:` |
| Source-app rail | People remember context, not time |
| Transform bar | json, b64, jwt, slug, url, markdown, clean — live in the preview |
| OCR search in images | Vision framework, no entitlement needed |

### v1.1 — after launch

Image quick actions (size/format badge, PNG↔JPG, resize, base64 data URI) ·
multi-select and paste-joined with a chosen separator · import from Maccy ·
frequency hint ("copied this three times, pin it?") · drag into the panel.

### v2 — later

Rule-based smart pinboards · Shortcuts actions · CLI · snippets and templates ·
AI and semantic search, last, and never in the name.

### Rejected outright

| Feature | Why |
|---|---|
| Fetching a URL's title and favicon | It would make the list far more readable, but it means a network request, and that punctures "the data never leaves your Mac" |
| iCloud sync | Not wanted; also removes the hardest part of the plan |
| Team sharing | This is a personal tool |
| Text expander | A different app |

## App Store metadata

| Field | Limit | Value |
|---|---|---|
| App name | 30 chars | `Pano: Clipboard Manager` (23) |
| Subtitle | 30 chars | `Free, local, open source` (24) |
| Keywords | 100 chars | `history,paste,copy,snippet,pasteboard,productivity,developer,privacy,local,ocr` (78) |
| Bundle display name | — | `Pano` — `CFBundleDisplayName`, so the system only ever shows "Pano" |

Do not repeat words from the name or subtitle in the keyword field; App Store
search indexes those already. No spaces after the commas — they cost characters.
