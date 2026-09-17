import PanoStore
import Testing

@testable import PanoCore

@Test func classifiesColour() {
    #expect(ClipClassifier.kind(utis: ["public.utf8-plain-text"], text: "#FF8800") == .colour)
    #expect(ClipClassifier.kind(utis: ["public.utf8-plain-text"], text: "#fff") == .colour)
    #expect(ClipClassifier.kind(utis: ["public.utf8-plain-text"], text: "rgb(255, 136, 0)") == .colour)
}

@Test func classifiesURL() {
    #expect(ClipClassifier.kind(utis: ["public.utf8-plain-text"], text: "https://pano.app/docs") == .url)
    #expect(ClipClassifier.kind(utis: ["public.utf8-plain-text"], text: "not a url just words") == .text)
}

@Test func fileBeatsAccompanyingText() {
    // Finder puts the filename on the pasteboard as text alongside the file URL; file wins.
    let utis: Set = ["public.file-url", "public.utf8-plain-text"]
    #expect(ClipClassifier.kind(utis: utis, text: "photo.jpg") == .file)
}

@Test func classifiesImageAndRichTextAndText() {
    #expect(ClipClassifier.kind(utis: ["public.png"], text: nil) == .image)
    #expect(ClipClassifier.kind(utis: ["public.rtf", "public.utf8-plain-text"], text: "bold") == .richtext)
    #expect(ClipClassifier.kind(utis: ["public.utf8-plain-text"], text: "hello") == .text)
}
