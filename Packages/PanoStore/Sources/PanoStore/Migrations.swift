import Foundation
import GRDB

/// The schema is defined here as raw SQL migrations, one per change, never edited once
/// shipped (docs/03-data-model.md). Migration identifiers are part of the contract with
/// every user's existing database.
enum Migrations {
    static func migrator() -> DatabaseMigrator {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1-schema") { db in
            try db.execute(
                sql: """
                    CREATE TABLE clip (
                        id               INTEGER PRIMARY KEY,
                        kind             TEXT NOT NULL,
                        content          TEXT,
                        byte_size        INTEGER NOT NULL,
                        content_hash     TEXT NOT NULL,
                        source_bundle_id TEXT,
                        source_name      TEXT,
                        language         TEXT,
                        ocr_text         TEXT,
                        is_pinned        INTEGER NOT NULL DEFAULT 0,
                        is_masked        INTEGER NOT NULL DEFAULT 0,
                        sensitivity      TEXT NOT NULL DEFAULT 'none',
                        copy_count       INTEGER NOT NULL DEFAULT 1,
                        created_at       REAL NOT NULL,
                        last_seen_at     REAL NOT NULL,
                        expires_at       REAL
                    );

                    CREATE TABLE clip_content (
                        clip_id   INTEGER NOT NULL REFERENCES clip(id) ON DELETE CASCADE,
                        position  INTEGER NOT NULL,
                        uti       TEXT NOT NULL,
                        data      BLOB,
                        blob_path TEXT,
                        byte_size INTEGER NOT NULL,
                        PRIMARY KEY (clip_id, position)
                    );

                    CREATE INDEX idx_content_blob ON clip_content(blob_path) WHERE blob_path IS NOT NULL;
                    CREATE UNIQUE INDEX idx_clip_hash ON clip(content_hash);
                    CREATE INDEX idx_clip_last_seen ON clip(last_seen_at DESC);
                    CREATE INDEX idx_clip_source    ON clip(source_bundle_id, last_seen_at DESC);
                    CREATE INDEX idx_clip_kind      ON clip(kind, last_seen_at DESC);
                    CREATE INDEX idx_clip_expiry    ON clip(expires_at) WHERE expires_at IS NOT NULL;
                    CREATE INDEX idx_clip_pinned    ON clip(is_pinned, last_seen_at DESC) WHERE is_pinned = 1;

                    CREATE VIRTUAL TABLE clip_fts USING fts5(
                        content,
                        ocr_text,
                        content = 'clip',
                        content_rowid = 'id',
                        tokenize = 'unicode61 remove_diacritics 2'
                    );

                    CREATE TRIGGER clip_ai AFTER INSERT ON clip BEGIN
                        INSERT INTO clip_fts(rowid, content, ocr_text)
                        VALUES (new.id, new.content, new.ocr_text);
                    END;
                    CREATE TRIGGER clip_ad AFTER DELETE ON clip BEGIN
                        INSERT INTO clip_fts(clip_fts, rowid, content, ocr_text)
                        VALUES ('delete', old.id, old.content, old.ocr_text);
                    END;
                    CREATE TRIGGER clip_au AFTER UPDATE ON clip BEGIN
                        INSERT INTO clip_fts(clip_fts, rowid, content, ocr_text)
                        VALUES ('delete', old.id, old.content, old.ocr_text);
                        INSERT INTO clip_fts(rowid, content, ocr_text)
                        VALUES (new.id, new.content, new.ocr_text);
                    END;

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
                        bundle_id      TEXT PRIMARY KEY,
                        display_name   TEXT NOT NULL,
                        excluded_kinds TEXT
                    );
                    """
            )
        }

        return migrator
    }
}
