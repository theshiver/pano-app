import Foundation
import PanoStore
import Testing

@testable import PanoCore

private func input(_ pairs: [(String, Data)], bundle: String? = nil) -> CaptureBuilder.Input {
    CaptureBuilder.Input(
        utis: pairs.map(\.0),
        data: Dictionary(uniqueKeysWithValues: pairs),
        sourceBundleId: bundle
    )
}

private func text(_ s: String) -> Data { Data(s.utf8) }

@Test func concealedCopyIsNotRecorded() {
    let out = CaptureBuilder.build(
        input([("org.nspasteboard.ConcealedType", Data()), ("public.utf8-plain-text", text("hunter2"))])
    )
    #expect(out == nil)
}

@Test func dropsNonWhitelistedTypes() {
    let out = CaptureBuilder.build(
        input([
            ("public.utf8-plain-text", text("hi")),
            ("com.apple.finder.noderef", Data([1, 2, 3])),
            ("dyn.abc123", Data([4])),
        ])
    )
    #expect(out != nil)
    #expect(out!.representations.map(\.uti) == ["public.utf8-plain-text"])
}

@Test func pngWinsOverTIFF() {
    let out = CaptureBuilder.build(
        input([("public.tiff", Data(count: 10)), ("public.png", Data(count: 5))])
    )
    #expect(out?.representations.map(\.uti) == ["public.png"])
    #expect(out?.kind == .image)
}

@Test func keepsTIFFWhenItIsTheOnlyImage() {
    let out = CaptureBuilder.build(input([("public.tiff", Data(count: 10))]))
    #expect(out?.representations.map(\.uti) == ["public.tiff"])
}

@Test func nothingWhitelistedYieldsNil() {
    #expect(CaptureBuilder.build(input([("dyn.abc", Data([1]))])) == nil)
}

@Test func secretSetsSensitivityAndMask() {
    let out = CaptureBuilder.build(input([("public.utf8-plain-text", text("ghp_16CharsOfTokenABCDEFGHIJ1234567890"))]))
    #expect(out?.sensitivity == .secret)
    #expect(out?.isMasked == true)
}

@Test func preservesRepresentationOrder() {
    let out = CaptureBuilder.build(
        input([
            ("public.rtf", text("{\\rtf}")), ("public.html", text("<b>x</b>")), ("public.utf8-plain-text", text("x")),
        ])
    )
    #expect(out?.representations.map(\.uti) == ["public.rtf", "public.html", "public.utf8-plain-text"])
    #expect(out?.kind == .richtext)
}

@Test func maskSecretsOffStoresSecretsAsPlainText() {
    let jwt =
        "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c"
    let pairs = [("public.utf8-plain-text", text(jwt))]
    #expect(CaptureBuilder.build(input(pairs))?.isMasked == true)
    let plain = CaptureBuilder.build(input(pairs), maskSecrets: false)
    #expect(plain?.isMasked == false)
    #expect(plain?.sensitivity == Clip.Sensitivity.none)
}
