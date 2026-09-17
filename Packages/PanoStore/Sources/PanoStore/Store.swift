import CryptoKit
import Foundation
import GRDB

/// The database actor (docs/02-architecture.md). Owns `pano.sqlite` and the sibling
/// `Blobs/` directory, applies migrations, and serialises every read and write.
public actor Store {
    private let dbQueue: DatabaseQueue
    private let blobsURL: URL
    private let retention: RetentionRules

    /// Opens (or creates) the database and blob directory inside `folder`.
    public init(folder: URL, retention: RetentionRules = RetentionRules()) throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        self.blobsURL = folder.appendingPathComponent("Blobs", isDirectory: true)
        try FileManager.default.createDirectory(at: blobsURL, withIntermediateDirectories: true)

        var config = Configuration()
        config.foreignKeysEnabled = true
        self.dbQueue = try DatabaseQueue(path: folder.appendingPathComponent("pano.sqlite").path, configuration: config)
        self.retention = retention
        try Migrations.migrator().migrate(dbQueue)
    }

    // MARK: Insert with dedup

    /// Inserts a capture, or, when an identical payload already exists, bumps its
    /// `copy_count` and `last_seen_at` and returns the existing row's id.
    @discardableResult
    public func insert(_ capture: ClipCapture, now: Date = Date()) throws -> Int64 {
        try dbQueue.write { db in try self.insertOne(capture, now: now, db: db) }
    }

    /// Insert many captures in a single transaction (bulk import, seeding). Returns the row ids.
    @discardableResult
    public func insertAll(_ captures: [ClipCapture], now: Date = Date()) throws -> [Int64] {
        try dbQueue.write { db in try captures.map { try self.insertOne($0, now: now, db: db) } }
    }

    private func insertOne(_ capture: ClipCapture, now: Date, db: Database) throws -> Int64 {
        let hash = Self.canonicalHash(capture)
        if let existing = try Clip.filter(Clip.Columns.contentHash == hash).fetchOne(db), let id = existing.id {
            try db.execute(
                sql: "UPDATE clip SET copy_count = copy_count + 1, last_seen_at = ? WHERE id = ?",
                arguments: [now, id]
            )
            return id
        }

        var clip = Clip(
            id: nil,
            kind: capture.kind,
            content: capture.content,
            byteSize: capture.representations.reduce(0) { $0 + $1.data.count },
            contentHash: hash,
            sourceBundleId: capture.sourceBundleId,
            sourceName: capture.sourceName,
            language: capture.language,
            ocrText: nil,
            isPinned: false,
            isMasked: capture.isMasked,
            sensitivity: capture.sensitivity,
            copyCount: 1,
            createdAt: now,
            lastSeenAt: now,
            expiresAt: retention.expiry(for: capture, from: now)
        )
        try clip.insert(db)
        let clipId = clip.id ?? db.lastInsertedRowID

        for (position, rep) in capture.representations.enumerated() {
            let (data, blobPath) = try persist(rep, clipId: clipId, position: position)
            try ClipContent(
                clipId: clipId, position: position, uti: rep.uti,
                data: data, blobPath: blobPath, byteSize: rep.data.count
            ).insert(db)
        }
        return clipId
    }

    /// Small representations stay inline; large ones are written to `Blobs/` and referenced by path.
    private func persist(_ rep: ClipCapture.Representation, clipId: Int64, position: Int) throws -> (Data?, String?) {
        guard rep.data.count >= ClipContent.inlineThreshold else {
            return (rep.data, nil)
        }
        let name = "\(clipId)-\(position).bin"
        try rep.data.write(to: blobsURL.appendingPathComponent(name), options: .atomic)
        return (nil, name)
    }

    // MARK: Reads

    public func recent(limit: Int = 200) throws -> [ClipListItem] {
        try dbQueue.read { db in
            try ClipListItem.fetchAll(
                db,
                sql:
                    "SELECT \(ClipListItem.columns) FROM clip ORDER BY clip.is_pinned DESC, clip.last_seen_at DESC LIMIT ?",
                arguments: [limit]
            )
        }
    }

    /// Full-text search over content and OCR text.
    ///
    /// Results are ordered newest-first by **id** (first-seen), not `last_seen_at`. This lets FTS
    /// pick the top `limit` rowids itself and join to `clip` for only those rows, instead of
    /// sorting every match by an orthogonal column — the difference between ~17 ms and <2 ms at
    /// 100k rows (see BenchmarkTests). A re-copied old item therefore keeps its place in *search*
    /// results; the main history list (`recent`) still orders by `last_seen_at`. clip.id is a
    /// monotonic rowid, so id DESC is a faithful first-seen recency order.
    public func search(_ text: String, limit: Int = 200) throws -> [ClipListItem] {
        let pattern = FTS5Pattern(matchingAllPrefixesIn: text)
        guard let pattern else { return [] }
        return try dbQueue.read { db in
            try ClipListItem.fetchAll(
                db,
                sql: """
                    SELECT \(ClipListItem.columns) FROM clip
                    WHERE clip.id IN (
                        SELECT rowid FROM clip_fts WHERE clip_fts MATCH ? ORDER BY rowid DESC LIMIT ?
                    )
                    ORDER BY clip.id DESC
                    """,
                arguments: [pattern, limit]
            )
        }
    }

    public func contents(of clipId: Int64) throws -> [ClipContent] {
        try dbQueue.read { db in
            try ClipContent.filter(Column("clip_id") == clipId).order(Column("position")).fetchAll(db)
        }
    }

    /// The stored representations of a clip, in order, with their bytes loaded (inline or from a
    /// blob file). This is what PasteService writes back to the pasteboard.
    public func payload(of clipId: Int64) throws -> [(uti: String, data: Data)] {
        try contents(of: clipId).map { content in
            if let data = content.data {
                return (content.uti, data)
            }
            guard let name = content.blobPath else { return (content.uti, Data()) }
            let data = try Data(contentsOf: blobsURL.appendingPathComponent(name))
            return (content.uti, data)
        }
    }

    public func count() throws -> Int {
        try dbQueue.read { db in try Clip.fetchCount(db) }
    }

    // MARK: Mutations

    public func setPinned(_ isPinned: Bool, id: Int64) throws {
        _ = try dbQueue.write { db in
            try db.execute(sql: "UPDATE clip SET is_pinned = ? WHERE id = ?", arguments: [isPinned, id])
        }
    }

    /// Deletes one clip and unlinks its blob files. `ON DELETE CASCADE` removes the content rows.
    public func delete(id: Int64) throws {
        let blobs = try dbQueue.write { db -> [String] in
            let paths = try String.fetchAll(
                db,
                sql: "SELECT blob_path FROM clip_content WHERE clip_id = ? AND blob_path IS NOT NULL",
                arguments: [id]
            )
            try db.execute(sql: "DELETE FROM clip WHERE id = ?", arguments: [id])
            return paths
        }
        for name in blobs {
            try? FileManager.default.removeItem(at: blobsURL.appendingPathComponent(name))
        }
    }

    /// Clears the history: deletes every unpinned clip and its blob files, leaving pinned items.
    /// Returns the number of clips removed.
    @discardableResult
    public func clearHistory() throws -> Int {
        let (deleted, blobs) = try dbQueue.write { db -> (Int, [String]) in
            let ids = try Int64.fetchAll(db, sql: "SELECT id FROM clip WHERE is_pinned = 0")
            guard !ids.isEmpty else { return (0, []) }
            let list = ids.map { "\($0)" }.joined(separator: ",")
            let paths = try String.fetchAll(
                db,
                sql: "SELECT blob_path FROM clip_content WHERE clip_id IN (\(list)) AND blob_path IS NOT NULL"
            )
            try db.execute(sql: "DELETE FROM clip WHERE id IN (\(list))")
            return (ids.count, paths)
        }
        for name in blobs {
            try? FileManager.default.removeItem(at: blobsURL.appendingPathComponent(name))
        }
        return deleted
    }

    // MARK: Retention

    /// Deletes expired, unpinned clips and their orphaned blob files. Returns rows deleted.
    /// `ON DELETE CASCADE` removes the `clip_content` rows; the blob files it points to are on
    /// disk, so their names are collected before the delete and unlinked afterwards.
    @discardableResult
    public func sweepExpired(now: Date = Date()) throws -> Int {
        let (deleted, orphanedBlobs) = try dbQueue.write { db -> (Int, [String]) in
            let ids = try Int64.fetchAll(
                db,
                sql: "SELECT id FROM clip WHERE expires_at IS NOT NULL AND expires_at < ? AND is_pinned = 0",
                arguments: [now]
            )
            guard !ids.isEmpty else { return (0, []) }
            let list = ids.map { "\($0)" }.joined(separator: ",")
            let paths = try String.fetchAll(
                db,
                sql: "SELECT blob_path FROM clip_content WHERE clip_id IN (\(list)) AND blob_path IS NOT NULL"
            )
            try db.execute(sql: "DELETE FROM clip WHERE id IN (\(list))")
            return (ids.count, paths)
        }
        for name in orphanedBlobs {
            try? FileManager.default.removeItem(at: blobsURL.appendingPathComponent(name))
        }
        return deleted
    }

    // MARK: Hashing

    /// SHA-256 over the text form when present, otherwise the first representation's bytes.
    static func canonicalHash(_ capture: ClipCapture) -> String {
        let bytes: Data
        if let content = capture.content, let utf8 = content.data(using: .utf8) {
            bytes = utf8
        } else {
            bytes = capture.representations.first?.data ?? Data()
        }
        return SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
    }
}
