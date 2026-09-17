import Foundation
import Testing

@testable import PanoStore

/// Week 2 exit criterion (docs/06-roadmap.md): a three-character prefix search over 100,000
/// rows returns in under 10 ms on Apple silicon. Written before the UI exists.
///
/// The corpus is a realistic vocabulary rather than a handful of repeated words, so a
/// three-character prefix matches a plausible slice instead of 10% of the table. The test
/// prints the match count so the breadth of the query is visible, not hidden.
@Test(
    "search under 10 ms at 100k rows",
    .enabled(if: ProcessInfo.processInfo.environment["PANO_BENCH"] != nil)
)
func searchUnder10msAt100kRows() async throws {
    let folder = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("pano-bench-\(UUID().uuidString)", isDirectory: true)
    let store = try Store(folder: folder)
    defer { try? FileManager.default.removeItem(at: folder) }

    var rng = SystemRandomNumberGenerator()
    let now = Date()
    var captures: [ClipCapture] = []
    captures.reserveCapacity(100_000)
    for i in 0..<100_000 {
        let count = Int.random(in: 6...14, using: &rng)
        var line: [String] = []
        for _ in 0..<count { line.append(benchmarkVocabulary.randomElement(using: &rng)!) }
        let s = line.joined(separator: " ") + " \(i)"
        captures.append(
            ClipCapture(
                kind: .text, content: s,
                representations: [.init(uti: "public.utf8-plain-text", data: Data(s.utf8))]
            )
        )
    }
    try await store.insertAll(captures, now: now)
    #expect(try await store.count() == 100_000)

    _ = try await store.search("con")  // warm
    var timings: [Double] = []
    var matchCount = 0
    for _ in 0..<7 {
        let t0 = DispatchTime.now()
        let hits = try await store.search("con")
        timings.append(Double(DispatchTime.now().uptimeNanoseconds - t0.uptimeNanoseconds) / 1_000_000)
        matchCount = hits.count
    }
    let median = timings.sorted()[timings.count / 2]
    print(
        "median 3-char prefix search over 100k rows: "
            + "\(String(format: "%.2f", median)) ms (\(matchCount) rows returned, limit 200)"
    )
    #expect(median < 10.0)
}

/// ~180 common English and Turkish words, the sort of thing that lands on a developer's
/// clipboard. Enough variety that a three-character prefix matches a realistic fraction.
private let benchmarkVocabulary: [String] = """
    the of and to in that have for not with you this but his from they say her she will one all would there their what out about who get which when make can like time just him know take people into year your good some could them see other than then now look only come its over think also back after use two how our work first well way even new want because any these give day most us swift pasteboard clipboard database retention transform function struct enum protocol closure actor concurrency sandbox entitlement accessibility migration index query select insert delete update commit branch merge review deploy release version build test error warning result value reference pointer memory buffer stream socket request response header token session cookie cache render layout constraint gesture window panel button label field toggle picker istanbul ankara izmir görüntü sayfa dosya kopyala yapıştır pano geçmiş arama filtre ayarlar bağlantı görsel metin biçim renk boyut konum sürükle bırak seçim liste satır sütun başlık açıklama örnek deneme kayıt silme güncelleme sürüm dal birleştir gözden geçir dağıt yayın hata uyarı sonuç değer bellek istek yanıt oturum önbellek
    """.split(separator: " ").map(String.init)
