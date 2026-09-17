# ADR 0002 — GRDB with SQLite FTS5, not SwiftData

**Status:** accepted · 2026-09-16

## Context

A clipboard manager's core interaction is search. Histories reach tens of
thousands of rows, with mixed text, code, images and OCR output.

SwiftData was the obvious fast path while iCloud sync was in scope, because it
gives CloudKit synchronisation nearly for free.

## Decision

GRDB over SQLite, with an FTS5 external-content index.

## Rationale

- Sync is gone (ADR 0001), and it was SwiftData's only decisive advantage here.
- Full-text search is a first-class SQLite feature and a bolt-on everywhere else.
  Search is the heart of this app; borrowing that layer would be the wrong place
  to save effort.
- Under CloudKit, SwiftData requires every property to be optional or defaulted
  and forbids unique constraints. The schema wants a unique index on
  `content_hash` for deduplication.
- Full control of indices, triggers and migrations, which matters for the
  100,000-row performance target.
- GRDB is mature, well documented, and a single dependency.

## Consequences

- Migrations are written by hand with `DatabaseMigrator`. A shipped migration is
  never edited.
- The FTS table is kept in sync by SQL triggers declared in the migration, not by
  Swift code that can be forgotten.
- One third-party dependency enters the project. It is the only one currently
  justified.
