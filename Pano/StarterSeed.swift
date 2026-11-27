import AppKit
import Foundation
import PanoCore
import PanoStore

enum StarterSeed {
    static func seedIfEmpty(_ store: Store) async {
        let count = (try? await store.count()) ?? 1
        guard count == 0 else { return }

        let now = Date()
        var samples: [ClipCapture] = [
            ClipCapture(
                kind: .code,
                content: #"{"service":"pano","localOnly":true,"ocr":true,"transforms":["json","jwt","b64"]}"#,
                representations: [
                    .init(
                        uti: "public.utf8-plain-text",
                        data: Data(
                            #"{"service":"pano","localOnly":true,"ocr":true,"transforms":["json","jwt","b64"]}"#.utf8)
                    )
                ],
                sourceBundleId: "com.apple.Terminal",
                sourceName: "Terminal"
            ),
            ClipCapture(
                kind: .colour,
                content: "#E6563D",
                representations: [.init(uti: "public.utf8-plain-text", data: Data("#E6563D".utf8))],
                sourceBundleId: "com.apple.Safari",
                sourceName: "Safari"
            ),
        ]

        if let png = renderSampleErrorPNG() {
            samples.append(
                ClipCapture(
                    kind: .image,
                    content: nil,
                    representations: [.init(uti: "public.png", data: png)],
                    sourceBundleId: "com.apple.dt.Xcode",
                    sourceName: "Xcode"
                )
            )
        }

        let ids = (try? await store.insertAll(samples, now: now)) ?? []
        if let imageId = ids.last, samples.count == 3,
            let png = samples[2].representations.first?.data,
            let text = await OCRService.recognizeText(in: png)
        {
            try? await store.setOCRText(text, id: imageId)
        }
    }

    private static func renderSampleErrorPNG() -> Data? {
        let size = NSSize(width: 680, height: 180)
        guard
            let rep = NSBitmapImageRep(
                bitmapDataPlanes: nil, pixelsWide: Int(size.width), pixelsHigh: Int(size.height),
                bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
            )
        else { return nil }
        rep.size = size
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

        NSColor(red: 0.13, green: 0.14, blue: 0.18, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(origin: .zero, size: size), xRadius: 12, yRadius: 12).fill()

        let lines: [(String, NSColor, CGFloat)] = [
            ("error: cannot find 'ClipListItem' in scope", NSColor(red: 0.96, green: 0.44, blue: 0.36, alpha: 1), 116),
            ("  --> PanoUI/Sources/ClipRow.swift:14:20", NSColor(white: 0.78, alpha: 1), 82),
            (
                "help: try searching 'ClipListItem' to test OCR", NSColor(red: 0.38, green: 0.82, blue: 0.60, alpha: 1),
                44
            ),
        ]
        let font = NSFont.monospacedSystemFont(ofSize: 18, weight: .medium)
        for (text, color, y) in lines {
            NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: color])
                .draw(at: NSPoint(x: 28, y: y))
        }
        NSGraphicsContext.restoreGraphicsState()
        return rep.representation(using: .png, properties: [:])
    }
}
