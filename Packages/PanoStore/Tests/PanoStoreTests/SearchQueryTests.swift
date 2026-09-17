import Foundation
import Testing

@testable import PanoStore

@Test func parsesFiltersAndTerms() {
    let q = SearchQuery(parsing: "app:Safari type:url pinned: >7d hello world")
    #expect(q.app == "Safari")
    #expect(q.kind == .url)
    #expect(q.pinnedOnly)
    #expect(q.olderThan == 7 * 86_400.0)
    #expect(q.terms == "hello world")
    #expect(q.hasFilters)
}

@Test func parsesNewerThanAndUnits() {
    #expect(SearchQuery(parsing: "<2h").newerThan == 2 * 3_600.0)
    #expect(SearchQuery(parsing: ">30m").olderThan == 30 * 60.0)
    #expect(SearchQuery(parsing: "type:color").kind == .colour)
    #expect(!SearchQuery(parsing: "just text").hasFilters)
}

private func store() throws -> (Store, URL) {
    let folder = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("pano-sq-\(UUID().uuidString)")
    return (try Store(folder: folder), folder)
}

private func clip(_ text: String, kind: Clip.Kind = .text, app: String? = nil) -> ClipCapture {
    ClipCapture(
        kind: kind, content: text,
        representations: [.init(uti: "public.utf8-plain-text", data: Data(text.utf8))],
        sourceBundleId: app, sourceName: app
    )
}

@Test func filtersByType() async throws {
    let (s, folder) = try store()
    defer { try? FileManager.default.removeItem(at: folder) }
    try await s.insert(clip("https://a.com", kind: .url))
    try await s.insert(clip("plain note", kind: .text))
    let urls = try await s.search("type:url")
    #expect(urls.count == 1)
    #expect(urls[0].kind == .url)
}

@Test func filtersByAppAndTermTogether() async throws {
    let (s, folder) = try store()
    defer { try? FileManager.default.removeItem(at: folder) }
    try await s.insert(clip("invoice number 42", app: "Safari"))
    try await s.insert(clip("invoice draft", app: "Mail"))
    let hits = try await s.search("app:Safari invoice")
    #expect(hits.count == 1)
    #expect(hits[0].sourceName == "Safari")
}

@Test func filtersByAge() async throws {
    let (s, folder) = try store()
    defer { try? FileManager.default.removeItem(at: folder) }
    let now = Date()
    try await s.insert(clip("old"), now: now.addingTimeInterval(-10 * 86_400))
    try await s.insert(clip("recent"), now: now)
    #expect(try await s.search(">7d", now: now).map(\.content) == ["old"])
    #expect(try await s.search("<1h", now: now).map(\.content) == ["recent"])
}

@Test func pinnedFilter() async throws {
    let (s, folder) = try store()
    defer { try? FileManager.default.removeItem(at: folder) }
    let id = try await s.insert(clip("keep me"))
    try await s.insert(clip("temporary"))
    try await s.setPinned(true, id: id)
    let pinned = try await s.search("pinned:")
    #expect(pinned.count == 1)
    #expect(pinned[0].content == "keep me")
}
