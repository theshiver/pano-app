# Architecture

## Shape

One app target, four local Swift packages, no server, no network.

```
┌──────────────────────────────────────────────────────────┐
│ Pano (app target)                                        │
│   AppDelegate · hotkey registration · onboarding · wiring │
└───────────┬──────────────────────────────┬───────────────┘
            │                              │
    ┌───────▼────────┐            ┌────────▼────────┐
    │ PanoCore       │            │ PanoUI          │
    │ capture loop   │            │ NSPanel host    │
    │ type parsing   │            │ list · preview  │
    │ privacy rules  │            │ settings        │
    │ paste service  │            │ onboarding      │
    └───────┬────────┘            └────────┬────────┘
            │                              │
    ┌───────▼────────┐            ┌────────▼────────┐
    │ PanoStore      │            │ PanoTransforms  │
    │ GRDB schema    │            │ json b64 jwt    │
    │ FTS5 queries   │            │ slug url md     │
    │ retention      │            │ clean · colour  │
    └────────────────┘            └─────────────────┘
```

`PanoTransforms` depends on nothing. `PanoStore` depends on GRDB only.
`PanoCore` depends on `PanoStore`. `PanoUI` depends on `PanoCore` and
`PanoTransforms`. The app target depends on all four and owns nothing but wiring.

## Capture

There is no notification API for pasteboard changes. Poll
`NSPasteboard.general.changeCount` on a 0.5 s timer. Idle cost is negligible and
no entitlement is required.

The loop is an `actor`. On each tick:

1. `changeCount` unchanged → return.
2. Check the concealed and transient types first. If either is present, record
   nothing and return. This check comes before anything reads the payload.
3. Check the exclusion list against `NSWorkspace.shared.frontmostApplication`.
4. Read the richest representation available and classify:
   colour → URL → file → image → rich text → plain text.
5. Run sensitive-pattern detection (see `03-data-model.md`). A match sets the
   short retention rule and the masked flag.
6. Hash the payload. If the hash matches an existing row, bump that row's
   `copy_count` and `last_seen_at` instead of inserting.
7. Insert, and kick OCR onto a background task for images.

## The panel

`NSPanel` with `.nonactivatingPanel`, `.hudWindow` off, `level = .floating`,
`hidesOnDeactivate = false`, `collectionBehavior` including
`.canJoinAllSpaces` and `.fullScreenAuxiliary`.

The non-activating style is the whole game: if the panel takes key focus, the
app the user was typing in loses it and there is nothing to paste back into.
Content is SwiftUI inside an `NSHostingView`.

Position: centred on the screen that contains the mouse, biased toward the
cursor, clamped so the panel never crosses a screen edge.

## Paste-back

`PasteService.write(_:)` in `PanoCore`: the chosen payload goes on the
pasteboard, the item's stored types in their stored order, each file URL as its
own `NSPasteboardItem` via `writeObjects`, the rest on the first item with
`setData`. The panel hides first so the user is back in their app, and they
press ⌘V. Pano does not post the keystroke itself (`adr/0008`).

There is no snapshot and no restore. The chosen item is now the clipboard; the
capture loop notices the change and moves the item to the top of history by
hash match instead of inserting a duplicate.

## Search

The search field is a small parser, not a text box.

- Bare words → FTS5 `MATCH` against the content and OCR columns
- `app:<bundle-or-name>` → predicate on the source app
- `type:<text|image|file|url|colour|code>` → predicate on the kind column
- `>7d`, `<2h` → predicate on `created_at`
- `pinned:` → predicate on the pin flag
- A trailing bare token that matches a transform name (`json`, `b64`, …) selects
  that transform in the preview rather than filtering

Parse to a small `Query` struct; build SQL from that struct; never string-concatenate
user input into SQL.

## Transforms

Each transform is a value type conforming to one protocol:

```
protocol Transform {
    var id: String { get }             // "json", "b64", "colour"
    func applies(to item: ClipItem) -> Bool
    func apply(_ input: String) throws -> TransformOutput
}
```

`applies(to:)` decides whether the chip is even offered. Transforms are pure,
synchronous, and unit tested with real-world inputs — a genuinely ugly PDF
paste for `clean`, a real JWT for `jwt`.

Colour is the one transform with a richer output: it produces a set of named
representations rather than a single string, and the preview renders them as a
list with a swatch.

## Threading

- Capture loop: `actor CaptureEngine`
- Database: `actor Store` wrapping a GRDB `DatabaseQueue`
- OCR: detached background task, writes back through the store actor
- UI: `@MainActor` throughout

Swift 6 strict concurrency is on. If something needs `@unchecked Sendable`, that
is a design smell — raise it rather than annotating around it.

## What deliberately does not exist

No networking layer. No sync engine. No account or keychain-backed identity. No
analytics. No plugin host. If a task seems to need one of these, the task is
wrong — stop and ask.
