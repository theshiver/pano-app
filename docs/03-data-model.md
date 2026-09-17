# Data model

One SQLite file, GRDB, FTS5. Location:
`~/Library/Application Support/Pano/pano.sqlite`, WAL mode, file protection on.
Large binary representations live beside it in `Blobs/`, not in the database.

## Schema

A clip is metadata plus one or more **content representations**. The pasteboard
hands over several UTIs for one copy (rich text carries `public.rtf`,
`public.html`, `public.utf8-plain-text`; an image carries `public.png` and
`public.tiff`), and paste-back has to write them all so the target app picks its
preferred one (see `adr/0003`). A single `payload` column cannot hold that, so
the representations live in their own table, ordered.

```sql
CREATE TABLE clip (
    id              INTEGER PRIMARY KEY,
    kind            TEXT NOT NULL,        -- text|richtext|code|url|colour|image|file
    content         TEXT,                 -- the searchable text form; NULL for pure binary
    byte_size       INTEGER NOT NULL,     -- sum of all representations' bytes
    content_hash    TEXT NOT NULL,        -- SHA-256 of the canonical payload
    source_bundle_id TEXT,
    source_name     TEXT,
    language        TEXT,                 -- detected code language, NULL otherwise
    ocr_text        TEXT,                 -- filled asynchronously for images
    is_pinned       INTEGER NOT NULL DEFAULT 0,
    is_masked       INTEGER NOT NULL DEFAULT 0,   -- render as dots in the list
    sensitivity     TEXT NOT NULL DEFAULT 'none', -- none|secret|financial
    copy_count      INTEGER NOT NULL DEFAULT 1,
    created_at      REAL NOT NULL,
    last_seen_at    REAL NOT NULL,
    expires_at      REAL                  -- NULL means "never", set by the retention rule
);

-- One row per pasteboard representation, in the source app's preference order.
-- Small reps (text, rtf, html) sit inline in `data`; large binaries (png, tiff,
-- file bookmarks) go to `blob_path` and `data` is NULL. Exactly one of the two
-- is non-NULL. On paste-back these are written in `position` order; each
-- `public.file-url` becomes its own NSPasteboardItem, the rest go on the first.
CREATE TABLE clip_content (
    clip_id    INTEGER NOT NULL REFERENCES clip(id) ON DELETE CASCADE,
    position   INTEGER NOT NULL,   -- 0-based, the order item.types listed them
    uti        TEXT NOT NULL,      -- e.g. public.rtf, public.png, public.file-url
    data       BLOB,               -- inline bytes, or NULL when stored on disk
    blob_path  TEXT,               -- relative path under Blobs/, or NULL when inline
    byte_size  INTEGER NOT NULL,
    PRIMARY KEY (clip_id, position)
);

CREATE INDEX idx_content_blob ON clip_content(blob_path) WHERE blob_path IS NOT NULL;

CREATE UNIQUE INDEX idx_clip_hash ON clip(content_hash);
CREATE INDEX idx_clip_last_seen  ON clip(last_seen_at DESC);
CREATE INDEX idx_clip_source     ON clip(source_bundle_id, last_seen_at DESC);
CREATE INDEX idx_clip_kind       ON clip(kind, last_seen_at DESC);
CREATE INDEX idx_clip_expiry     ON clip(expires_at) WHERE expires_at IS NOT NULL;
CREATE INDEX idx_clip_pinned     ON clip(is_pinned, last_seen_at DESC) WHERE is_pinned = 1;

CREATE VIRTUAL TABLE clip_fts USING fts5(
    content,
    ocr_text,
    content = 'clip',
    content_rowid = 'id',
    tokenize = 'unicode61 remove_diacritics 2'
);

CREATE TABLE pinboard (
    id         INTEGER PRIMARY KEY,
    name       TEXT NOT NULL,
    colour     TEXT NOT NULL,
    icon       TEXT,
    sort_order INTEGER NOT NULL
);

CREATE TABLE pinboard_clip (
    pinboard_id INTEGER NOT NULL REFERENCES pinboard(id) ON DELETE CASCADE,
    clip_id     INTEGER NOT NULL REFERENCES clip(id) ON DELETE CASCADE,
    sort_order  INTEGER NOT NULL,
    PRIMARY KEY (pinboard_id, clip_id)
);

CREATE TABLE excluded_app (
    bundle_id     TEXT PRIMARY KEY,
    display_name  TEXT NOT NULL,
    excluded_kinds TEXT   -- JSON array; NULL or empty means every kind
);
```

Keep the FTS table in sync with `clip` through the standard external-content
triggers (`AFTER INSERT`, `AFTER DELETE`, `AFTER UPDATE`). Write them in the
migration, not in Swift.

`remove_diacritics 2` matters for Turkish: searching "sayfa" should find "şayfa"
and searching "goruntu" should find "görüntü".

## Which representations are stored

The capture loop keeps only this whitelist, in the order the pasteboard item
listed them: `public.file-url`, `public.html`, `public.png`, `public.rtf`,
`public.utf8-plain-text`, `public.tiff`. Everything else — `dyn.*`, Finder's
private `com.apple.finder.noderef`, app-specific flavours — is dropped, because
it is either irreproducible or noise (verified in the week 0 spike; keeping
`noderef` was what corrupted Finder file pastes).

**Images: PNG wins.** When an item carries both `public.png` and `public.tiff`,
store the PNG and drop the TIFF. TIFF from a screenshot or Preview is several MB
against a few hundred KB of PNG, and every target that accepts TIFF accepts PNG.
Keep TIFF only when it is the sole image representation on the pasteboard.

**Inline vs. blob.** A representation under 64 KB goes in `clip_content.data`;
at or above that it goes to a file under `Blobs/` and `data` is NULL. Text,
RTF and HTML are almost always inline; PNG, TIFF and file bookmarks are almost
always on disk. The threshold is one constant, not a per-type rule.

**File URLs.** Store the security-scoped bookmark, not the raw path string, so a
file copied today still resolves after the app relaunches.

> **Entitlement decided (2026-09-17):** `com.apple.security.files.user-selected.read-only`
> is now in the entitlements (it was needed for the Settings app-picker too), so a
> user-chosen file's bookmark can be persisted and re-vended across launches. See
> `adr/0003`.

## Deduplication

`content_hash` is a SHA-256 over the canonical representation — the
`public.utf8-plain-text` bytes when there is a text form, otherwise the bytes of
the first stored representation. Hashing one representation, not all of them,
keeps dedup stable when an app varies a secondary flavour between copies. On a
collision with an existing row, do not insert: bump `copy_count`, set
`last_seen_at`, and leave `created_at` alone. This is what makes the v1.1
frequency hint possible without extra bookkeeping, and it is also how a
just-pasted item (which lands back on the pasteboard) folds into its existing
row instead of creating a duplicate — see `adr/0003`.

## Sensitive-pattern detection

Runs at insert time, over the text form only, before the row is written.

| Pattern | Detection | Result |
|---|---|---|
| Common API key prefixes (`sk-`, `ghp_`, `AKIA`, `xoxb-`, …) | Prefix plus length and charset check | `sensitivity = secret` |
| JWT | Three base64url segments separated by dots, first decodes to a JSON header | `secret` |
| Payment card number | 13–19 digits, passes Luhn | `financial` |
| IBAN | Country code, length table, mod-97 check | `financial` |

Anything other than `none` sets `is_masked = 1` and the short retention rule.
Detection is a heuristic and it will have false positives — that is the correct
trade, because the cost of a false positive is "this expired sooner than you
expected" and the cost of a false negative is a leaked key sitting in a database
for a month.

Concealed and transient pasteboard types are handled earlier, in the capture
loop, and never reach this stage.

## Retention

Defaults, all user-editable in Settings:

| Class | Default |
|---|---|
| `sensitivity != 'none'` | 1 hour |
| Images | 7 days |
| Everything else | 30 days |
| Pinned | never, regardless of the above |

`expires_at` is computed at insert and recomputed if the user changes a rule. A
sweep runs on launch and then hourly: delete expired rows, delete orphaned blobs,
then `PRAGMA optimize`. Run `VACUUM` only when the free-page ratio is high and
the app has been idle, never on the launch path.

## Performance target

100,000 rows, search latency under 10 ms for a three-character prefix query on
Apple silicon. This is week 2's exit criterion, so write the benchmark as a test
before the UI exists — retrofitting it later never happens.

Practical rules that keep it there: never `SELECT *` into the list; the list
query pulls only the columns the row view renders; images are loaded lazily by
path and thumbnailed once, with the thumbnail cached beside the blob.

## Migrations

GRDB `DatabaseMigrator`, one registered migration per schema change, never edit
a shipped migration. The migration identifiers are part of the public contract
with every user's existing database from the first App Store build onward.
