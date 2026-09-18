import CryptoKit
import Foundation
import GRDB

/// The database actor (docs/02-architecture.md). Owns `pano.sqlite` and the sibling
/// `Blobs/` directory, applies migrations, and serialises every read and write.
public actor Store {
    private let dbQueue: DatabaseQueue
    private let blobsURL: URL
    private var retention: RetentionRules

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

    /// Structured search: bare words hit the FTS index; `app:`/`type:`/`pinned:`/`>7d`/`<2h`
    /// become predicates (docs/02-architecture.md). Parsed to a `SearchQuery`, then SQL is built
    /// with bound parameters. A terms-only query keeps the fast top-N-rowids path (<2ms at 100k).
    public func search(_ raw: String, limit: Int = 200, now: Date = Date()) throws -> [ClipListItem] {
        let query = SearchQuery(parsing: raw)
        let trimmedTerms = query.terms.trimmingCharacters(in: .whitespaces)

        if !query.hasFilters {
            if trimmedTerms.isEmpty { return try recent(limit: limit) }
            return try ftsOnly(trimmedTerms, limit: limit)
        }
        return try filtered(query, terms: trimmedTerms, limit: limit, now: now)
    }

    private func ftsOnly(_ terms: String, limit: Int) throws -> [ClipListItem] {
        guard let pattern = FTS5Pattern(matchingAllPrefixesIn: terms) else { return [] }
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

    private func filtered(_ query: SearchQuery, terms: String, limit: Int, now: Date) throws -> [ClipListItem] {
        var wheres: [String] = []
        var args: [DatabaseValueConvertible] = []

        if !terms.isEmpty, let pattern = FTS5Pattern(matchingAllPrefixesIn: terms) {
            wheres.append("clip.id IN (SELECT rowid FROM clip_fts WHERE clip_fts MATCH ?)")
            args.append(pattern)
        }
        if let app = query.app {
            wheres.append("(clip.source_bundle_id LIKE ? OR clip.source_name LIKE ?)")
            args.append("%\(app)%")
            args.append("%\(app)%")
        }
        if let kind = query.kind {
            wheres.append("clip.kind = ?")
            args.append(kind.rawValue)
        }
        if query.pinnedOnly {
            wheres.append("clip.is_pinned = 1")
        }
        if let olderThan = query.olderThan {
            wheres.append("clip.created_at < ?")
            args.append(now.addingTimeInterval(-olderThan))
        }
        if let newerThan = query.newerThan {
            wheres.append("clip.created_at > ?")
            args.append(now.addingTimeInterval(-newerThan))
        }

        let clause = wheres.isEmpty ? "1" : wheres.joined(separator: " AND ")
        args.append(limit)
        return try dbQueue.read { db in
            try ClipListItem.fetchAll(
                db,
                sql: """
                    SELECT \(ClipListItem.columns) FROM clip
                    WHERE \(clause)
                    ORDER BY clip.is_pinned DESC, clip.last_seen_at DESC
                    LIMIT ?
                    """,
                arguments: StatementArguments(args)
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

    /// Updates the retention windows applied to future inserts. Existing `expires_at` values are
    /// left as they are; a rule change takes effect from the next copy, which is enough for v1.
    public func setRetention(_ rules: RetentionRules) {
        retention = rules
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

    /// Writes OCR text for an image clip: sets `ocr_text` and fills `content` if it was empty, so the
    /// row shows the text and both FTS columns index it (the AFTER UPDATE trigger re-indexes).
    public func setOCRText(_ text: String, id: Int64) throws {
        _ = try dbQueue.write { db in
            try db.execute(
                sql: "UPDATE clip SET ocr_text = ?, content = COALESCE(content, ?) WHERE id = ?",
                arguments: [text, text, id]
            )
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

    // MARK: Exclusion list

    public func excludedApps() throws -> [ExcludedApp] {
        try dbQueue.read { db in
            try ExcludedApp.order(Column("display_name")).fetchAll(db)
        }
    }

    public func excludedBundleIds() throws -> Set<String> {
        try dbQueue.read { db in
            Set(try String.fetchAll(db, sql: "SELECT bundle_id FROM excluded_app"))
        }
    }

    public func addExcludedApp(bundleId: String, displayName: String) throws {
        _ = try dbQueue.write { db in
            try db.execute(
                sql:
                    "INSERT OR REPLACE INTO excluded_app (bundle_id, display_name, excluded_kinds) VALUES (?, ?, NULL)",
                arguments: [bundleId, displayName]
            )
        }
    }

    public func removeExcludedApp(bundleId: String) throws {
        _ = try dbQueue.write { db in
            try db.execute(sql: "DELETE FROM excluded_app WHERE bundle_id = ?", arguments: [bundleId])
        }
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

    /// SHA-256 identity for dedup. For text-like clips it hashes the text form. For files and images
    /// it hashes the first representation (the file URL or the image bytes) instead of the filename —
    /// otherwise two different files with the same name collide, and re-copying a file whose first
    /// capture lacked the image would keep returning the text-only row.
    static func canonicalHash(_ capture: ClipCapture) -> String {
        let bytes: Data
        switch capture.kind {
        case .image, .file:
            bytes = capture.representations.first?.data ?? Data(capture.content?.utf8 ?? "".utf8)
        default:
            if let content = capture.content, let utf8 = content.data(using: .utf8) {
                bytes = utf8
            } else {
                bytes = capture.representations.first?.data ?? Data()
            }
        }
        return SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
    }
}
