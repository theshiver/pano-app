// Generates Pano/Assets.xcassets/AppIcon.appiconset from code, so the icon is reproducible and
// needs no design tool: an accent-blue rounded square with a white clipboard glyph.
// Run: swift scripts/make-icon.swift
import AppKit

let sizes: [(Int, Int)] = [(16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2), (256, 1), (256, 2), (512, 1), (512, 2)]
let out = URL(fileURLWithPath: "Pano/Assets.xcassets/AppIcon.appiconset")
try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

func draw(px: Int) -> Data {
    let image = NSImage(size: NSSize(width: px, height: px))
    image.lockFocus()
    let s = CGFloat(px)
    // macOS icon grid: the squircle occupies ~80% of the canvas.
    let inset = s * 0.1
    let rect = NSRect(x: inset, y: inset, width: s - 2 * inset, height: s - 2 * inset)
    let path = NSBezierPath(roundedRect: rect, xRadius: rect.width * 0.225, yRadius: rect.width * 0.225)
    let gradient = NSGradient(
        starting: NSColor(red: 0x4A / 255, green: 0x8A / 255, blue: 0xFF / 255, alpha: 1),
        ending: NSColor(red: 0x1E / 255, green: 0x55 / 255, blue: 0xD0 / 255, alpha: 1))
    gradient?.draw(in: path, angle: -90)

    let config = NSImage.SymbolConfiguration(pointSize: s * 0.42, weight: .medium)
    if let symbol = NSImage(systemSymbolName: "doc.on.clipboard.fill", accessibilityDescription: nil)?
        .withSymbolConfiguration(config)
    {
        let tinted = NSImage(size: symbol.size, flipped: false) { r in
            symbol.draw(in: r)
            NSColor.white.set()
            r.fill(using: .sourceAtop)
            return true
        }
        let size = tinted.size
        tinted.draw(in: NSRect(x: (s - size.width) / 2, y: (s - size.height) / 2, width: size.width, height: size.height))
    }
    image.unlockFocus()
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(in: NSRect(x: 0, y: 0, width: px, height: px))
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

var entries: [[String: String]] = []
for (pt, scale) in sizes {
    let name = "icon_\(pt)x\(pt)@\(scale)x.png"
    try! draw(px: pt * scale).write(to: out.appendingPathComponent(name))
    entries.append(["size": "\(pt)x\(pt)", "idiom": "mac", "filename": name, "scale": "\(scale)x"])
}
let contents: [String: Any] = ["images": entries, "info": ["version": 1, "author": "xcode"]]
let json = try! JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
try! json.write(to: out.appendingPathComponent("Contents.json"))
print("wrote \(entries.count) icons")
