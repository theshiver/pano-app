import AppKit
import Foundation
import Testing

@testable import PanoCore

/// Renders known text into a PNG and checks Vision reads it back. Uses a large, high-contrast
/// string so the assertion is stable.
@Test(
    "recognises rendered text",
    .enabled(if: ProcessInfo.processInfo.environment["PANO_OCR"] != nil)
)
func recognisesRenderedText() async throws {
    let png = renderPNG("PANO OCR 2026")
    let text = await OCRService.recognizeText(in: png)
    #expect(text != nil)
    #expect(text?.uppercased().contains("PANO") == true)
}

@Test(
    "returns nil for image without text",
    .enabled(if: ProcessInfo.processInfo.environment["PANO_OCR"] != nil)
)
func returnsNilForImageWithoutText() async throws {
    let blank = renderPNG("")
    #expect(await OCRService.recognizeText(in: blank) == nil)
}

private func renderPNG(_ string: String) -> Data {
    let size = NSSize(width: 400, height: 100)
    let image = NSImage(size: size)
    image.lockFocus()
    NSColor.white.setFill()
    NSRect(origin: .zero, size: size).fill()
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.boldSystemFont(ofSize: 44), .foregroundColor: NSColor.black,
    ]
    (string as NSString).draw(at: NSPoint(x: 12, y: 28), withAttributes: attrs)
    image.unlockFocus()
    guard let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
        let png = rep.representation(using: .png, properties: [:])
    else { return Data() }
    return png
}
