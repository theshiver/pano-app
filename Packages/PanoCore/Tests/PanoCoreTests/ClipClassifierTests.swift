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

@Test func classifiesCodeConservatively() {
    let js = "function add(a, b) {\n  return a + b;\n}"
    #expect(ClipClassifier.kind(utis: ["public.utf8-plain-text"], text: js) == .code)
    // Prose is not code.
    #expect(ClipClassifier.kind(utis: ["public.utf8-plain-text"], text: "Let me know if that works for you.") == .text)
    // JSON stays text (its transform handles it), not code.
    #expect(ClipClassifier.kind(utis: ["public.utf8-plain-text"], text: "{\"a\": 1, \"b\": 2}") == .text)
}

@Test func codeFromEditorWithRichTextIsStillCode() {
    // IDEs put RTF/HTML on the pasteboard next to the plain code.
    let java = "public Response load() {\n  return new Response(x);\n}"
    #expect(ClipClassifier.kind(utis: ["public.rtf", "public.html", "public.utf8-plain-text"], text: java) == .code)
    // Plain rich text (prose) stays richtext.
    #expect(ClipClassifier.kind(utis: ["public.rtf", "public.utf8-plain-text"], text: "just bold prose") == .richtext)
}

@Test func markdownSourceIsCodeAndProseAboutSQLIsNot() {
    let md = "# Findings\n\n- Repos: `services`, `admin`\n- Symptom: update from where the public class was\n"
    #expect(ClipClassifier.kind(utis: ["public.utf8-plain-text"], text: md) == .code)
    let prose = "Please update the ticket from where we left it, and select the class you want."
    #expect(ClipClassifier.kind(utis: ["public.utf8-plain-text"], text: prose) == .text)
    #expect(ClipClassifier.kind(utis: ["public.utf8-plain-text"], text: "SELECT id FROM users WHERE x = 1;") == .code)
}
