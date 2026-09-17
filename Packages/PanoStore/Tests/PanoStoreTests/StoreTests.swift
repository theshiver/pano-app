import Foundation
import Testing

@testable import PanoStore

private func tempStore() throws -> (Store, URL) {
    let folder = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("pano-tests-\(UUID().uuidString)", isDirectory: true)
    return (try Store(folder: folder), folder)
}

private func text(_ s: String, bundle: String? = nil) -> ClipCapture {
    ClipCapture(
        kind: .text,
        content: s,
        representations: [.init(uti: "public.utf8-plain-text", data: Data(s.utf8))],
        sourceBundleId: bundle
    )
}

@Test func insertAndFetchRoundTrip() async throws {
    let (store, folder) = try tempStore()
    defer { try? FileManager.default.removeItem(at: folder) }

    try await store.insert(text("hello", bundle: "com.apple.Safari"))
    let rows = try await store.recent()
    #expect(rows.count == 1)
    #expect(rows[0].content == "hello")
    #expect(rows[0].sourceBundleId == "com.apple.Safari")
    #expect(rows[0].copyCount == 1)
}

@Test func duplicateBumpsCountInsteadOfInserting() async throws {
    let (store, folder) = try tempStore()
    defer { try? FileManager.default.removeItem(at: folder) }

    let first = try await store.insert(text("same"))
    let second = try await store.insert(text("same"))
    #expect(first == second)
    #expect(try await store.count() == 1)
    let rows = try await store.recent()
    #expect(rows[0].copyCount == 2)
}

@Test func fullTextSearchFindsContent() async throws {
    let (store, folder) = try tempStore()
    defer { try? FileManager.default.removeItem(at: folder) }

    try await store.insert(text("the quick brown fox"))
    try await store.insert(text("lazy dog"))
    #expect(try await store.search("quick").count == 1)
    #expect(try await store.search("qui").count == 1)  // prefix
    #expect(try await store.search("cat").isEmpty)
}

@Test func turkishDiacriticsAreFolded() async throws {
    let (store, folder) = try tempStore()
    defer { try? FileManager.default.removeItem(at: folder) }

    try await store.insert(text("görüntü şayfa"))
    #expect(try await store.search("goruntu").count == 1)
    #expect(try await store.search("sayfa").count == 1)
}

@Test func largeRepresentationGoesToBlobFile() async throws {
    let (store, folder) = try tempStore()
    defer { try? FileManager.default.removeItem(at: folder) }

    let big = Data(count: ClipContent.inlineThreshold + 10)
    let id = try await store.insert(
        ClipCapture(kind: .image, content: nil, representations: [.init(uti: "public.png", data: big)])
    )
    let contents = try await store.contents(of: id)
    #expect(contents.count == 1)
    #expect(contents[0].data == nil)
    #expect(contents[0].blobPath != nil)
    let onDisk = folder.appendingPathComponent("Blobs").appendingPathComponent(contents[0].blobPath!)
    #expect(FileManager.default.fileExists(atPath: onDisk.path))
}

@Test func smallRepresentationStaysInline() async throws {
    let (store, folder) = try tempStore()
    defer { try? FileManager.default.removeItem(at: folder) }

    let id = try await store.insert(text("inline me"))
    let contents = try await store.contents(of: id)
    #expect(contents[0].data != nil)
    #expect(contents[0].blobPath == nil)
}

@Test func sweepDeletesExpiredAndKeepsLive() async throws {
    let (store, folder) = try tempStore()
    defer { try? FileManager.default.removeItem(at: folder) }

    let past = Date(timeIntervalSinceNow: -40 * 24 * 60 * 60)  // inserted 40 days ago
    try await store.insert(text("old"), now: past)
    try await store.insert(text("fresh"))
    let deleted = try await store.sweepExpired()
    #expect(deleted == 1)
    let rows = try await store.recent()
    #expect(rows.count == 1)
    #expect(rows[0].content == "fresh")
}

@Test func sweepUnlinksOrphanedBlob() async throws {
    let (store, folder) = try tempStore()
    defer { try? FileManager.default.removeItem(at: folder) }

    let big = Data(count: ClipContent.inlineThreshold + 10)
    let past = Date(timeIntervalSinceNow: -40 * 24 * 60 * 60)
    let id = try await store.insert(
        ClipCapture(kind: .image, content: nil, representations: [.init(uti: "public.png", data: big)]),
        now: past
    )
    let name = try await store.contents(of: id)[0].blobPath!
    let onDisk = folder.appendingPathComponent("Blobs").appendingPathComponent(name)
    #expect(FileManager.default.fileExists(atPath: onDisk.path))
    try await store.sweepExpired()
    #expect(!FileManager.default.fileExists(atPath: onDisk.path))
}

@Test func secretRetentionIsShorterThanText() async throws {
    let (store, folder) = try tempStore()
    defer { try? FileManager.default.removeItem(at: folder) }

    // A secret copied two hours ago is already expired (1h rule); a plain text is not.
    let twoHoursAgo = Date(timeIntervalSinceNow: -2 * 60 * 60)
    var secret = text("sk-verysecret")
    secret.sensitivity = .secret
    try await store.insert(secret, now: twoHoursAgo)
    try await store.insert(text("normal"), now: twoHoursAgo)
    #expect(try await store.sweepExpired() == 1)
    #expect(try await store.recent()[0].content == "normal")
}

@Test func pinnedFloatsToTopAndSurvivesRetention() async throws {
    let (store, folder) = try tempStore()
    defer { try? FileManager.default.removeItem(at: folder) }

    let past = Date(timeIntervalSinceNow: -40 * 24 * 60 * 60)
    let oldId = try await store.insert(text("old but pinned"), now: past)
    try await store.insert(text("fresh"))
    try await store.setPinned(true, id: oldId)

    // Pinned first regardless of last_seen.
    #expect(try await store.recent().first?.content == "old but pinned")
    // Pinned survives the retention sweep.
    #expect(try await store.sweepExpired() == 0)
    #expect(try await store.count() == 2)
}

@Test func deleteRemovesClipAndBlob() async throws {
    let (store, folder) = try tempStore()
    defer { try? FileManager.default.removeItem(at: folder) }

    let big = Data(count: ClipContent.inlineThreshold + 10)
    let id = try await store.insert(
        ClipCapture(kind: .image, content: nil, representations: [.init(uti: "public.png", data: big)])
    )
    let blob = folder.appendingPathComponent("Blobs")
        .appendingPathComponent(try await store.contents(of: id)[0].blobPath!)
    #expect(FileManager.default.fileExists(atPath: blob.path))
    try await store.delete(id: id)
    #expect(try await store.count() == 0)
    #expect(!FileManager.default.fileExists(atPath: blob.path))
}
