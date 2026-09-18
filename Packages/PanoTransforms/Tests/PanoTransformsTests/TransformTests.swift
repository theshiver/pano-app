import Testing

@testable import PanoTransforms

@Test func jsonPrettyPrintsRealAPIResponse() throws {
    let input = #"{"name":"Can","langs":["swift","kotlin"],"active":true}"#
    let json = JSONTransform()
    #expect(json.applies(to: input))
    let out = try json.apply(input).text
    #expect(out.contains("\"active\" : true"))
    #expect(out.contains("  \"swift\""))  // indented array element
    #expect(!JSONTransform().applies(to: "just text"))
}

@Test func base64DecodesRealString() throws {
    let input = "SGVsbG8sIFBhbm8h"  // "Hello, Pano!"
    let b64 = Base64Transform()
    #expect(b64.applies(to: input))
    #expect(try b64.apply(input).text == "Hello, Pano!")
    #expect(!b64.applies(to: "not base64 at all !!!"))
    #expect(!b64.applies(to: "deadbeefdeadbeef"))  // valid-looking but decodes to non-text
}

@Test func jwtDecodesRealToken() throws {
    let jwt =
        "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9"
        + ".eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ"
        + ".SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c"
    let t = JWTTransform()
    #expect(t.applies(to: jwt))
    let out = try t.apply(jwt).text
    #expect(out.contains("\"alg\""))
    #expect(out.contains("\"name\""))
    #expect(out.contains("John Doe"))
    #expect(!t.applies(to: "a.b.c"))
}

@Test func urlDecodesAndEncodes() throws {
    let url = URLTransform()
    let encoded = "https://sahibinden.com/ara?q=arac%20kiralama"
    #expect(url.applies(to: encoded))
    #expect(try url.apply(encoded).text == "https://sahibinden.com/ara?q=arac kiralama")

    let plain = "https://example.com/a b"
    #expect(url.applies(to: plain))
    #expect(try url.apply(plain).text.contains("a%20b"))
}

@Test func slugifiesTurkishTitle() throws {
    let slug = SlugTransform()
    let input = "Merhaba Dünya! Bu bir Başlık"
    #expect(slug.applies(to: input))
    #expect(try slug.apply(input).text == "merhaba-dunya-bu-bir-baslik")
    #expect(!slug.applies(to: "already-a-slug"))
}

@Test func cleansPDFPaste() throws {
    let clean = CleanTransform()
    // A PDF paste: soft hyphens, CRLF, doubled spaces, trailing space, extra blank lines.
    let input = "The qui\u{00AD}ck  brown \r\nfox   \r\n\r\n\r\njumps "
    #expect(clean.applies(to: input))
    let out = try clean.apply(input).text
    #expect(!out.contains("\u{00AD}"))
    #expect(!out.contains("  "))
    #expect(!out.contains("\r"))
    #expect(!out.contains("\n\n\n"))
    #expect(!clean.applies(to: "already clean text"))
}

@Test func colourConvertsHexToAllFormats() throws {
    let colour = ColourTransform()
    #expect(colour.applies(to: "#2A6DF0"))
    let out = try colour.apply("#2A6DF0")
    let byLabel = Dictionary(uniqueKeysWithValues: out.formats.map { ($0.label, $0.value) })
    #expect(byLabel["HEX"] == "#2A6DF0")
    #expect(byLabel["RGB"] == "rgb(42, 109, 240)")
    #expect(byLabel["HSL"] == "hsl(220, 87%, 55%)")
    #expect(byLabel["SwiftUI"]?.contains("red: 0.165") == true)
}

@Test func colourParsesRGBAndHSLAndAlpha() throws {
    let colour = ColourTransform()
    #expect(try colour.apply("rgb(42, 109, 240)").text == "#2A6DF0")
    // hsl round-trips exactly for pure colours (rounded hsl of an arbitrary hex won't).
    #expect(try colour.apply("hsl(0, 100%, 50%)").text == "#FF0000")
    #expect(try colour.apply("hsl(120, 100%, 50%)").text == "#00FF00")
    let alpha = try colour.apply("rgba(0, 0, 0, 0.5)")
    #expect(alpha.text == "#00000080")
    #expect(!colour.applies(to: "not a colour"))
    #expect(colour.applies(to: "#fff"))
}

@Test func registryOffersOnlyApplicable() {
    let ids = Transforms.applicable(to: "#2A6DF0").map(\.id)
    #expect(ids.contains("colour"))
    #expect(!ids.contains("json"))
}

@Test func colourMapsToNearestTailwindClass() throws {
    let colour = ColourTransform()
    let exact = try colour.apply("#3B82F6").formats  // blue-500
    #expect(exact.contains(.init("Tailwind", "blue-500")))
    let near = try colour.apply("#3B82F0").formats
    #expect(near.contains(.init("Tailwind ≈", "blue-500")))
    #expect(try colour.apply("#000").formats.contains(.init("Tailwind", "black")))
}

@Test func markdownRendersHTMLWithPlainFallback() throws {
    let md = MarkdownTransform()
    let input = "# Title\n\nSome **bold** and `code` with a [link](https://x.y).\n\n- one\n- two\n\n1. first\n"
    #expect(md.applies(to: input))
    let out = try md.apply(input)
    #expect(out.text == "Title\n\nSome bold and code with a link.\n\none\ntwo\n\nfirst")
    #expect(
        out.html
            == "<h1>Title</h1><p>Some <strong>bold</strong> and <code>code</code> with a "
            + "<a href=\"https://x.y\">link</a>.</p><ul><li><p>one</p><li><p>two</p></ul><ol><li><p>first</p></ol>")
    #expect(!md.applies(to: "plain sentence, nothing to strip"))
    #expect(!md.applies(to: "a * b"))
}
