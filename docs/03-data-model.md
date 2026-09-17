# Data model

One SQLite file, GRDB, FTS5. Location:
`~/Library/Application Support/Pano/pano.sqlite`, WAL mode, file protection on.
Large image payloads live beside it in `Blobs/`, not in the database.

## Schema

```sql
CREATE TABLE clip (
    id              INTEGER PRIMARY KEY,
    kind            TEXT NOT NULL,        -- text|richtext|code|url|colour|image|file
    content         TEXT,                 -- the searchable text form; NULL for pure binary
    payload_path    TEXT,                 -- relative path under Blobs/ for image and file
    payload_types   TEXT NOT NULL,        -- JSON array of the original UTI list
    byte_size       INTEGER NOT NULL,
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

## Deduplication

`content_hash` is a SHA-256 over the canonical payload — the UTF-8 bytes for
text, the raw data for images. On a collision with an existing row, do not
insert: bump `copy_count`, set `last_seen_at`, and leave `created_at` alone.
This is what makes the v1.1 frequency hint possible without extra bookkeeping.

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
