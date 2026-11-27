import AppKit
import ImageIO
import PanoStore
import PanoTransforms
import SwiftUI

@MainActor
public final class PreviewCache {
    public static let shared = PreviewCache()

    private var richTexts: [Int64: AttributedString] = [:]
    private var richOrder: [Int64] = []

    private struct HighlightKey: Hashable {
        let id: Int64
        let theme: String
    }
    private var highlights: [HighlightKey: CodeText.Result] = [:]
    private var highlightOrder: [HighlightKey] = []

    private var markdownTexts: [Int64: AttributedString] = [:]
    private var markdownOrder: [Int64] = []

    private var images: [Int64: NSImage] = [:]
    private var imageOrder: [Int64] = []

    private var thumbnails: [Int64: NSImage] = [:]
    private var thumbnailOrder: [Int64] = []

    private var languages: [Int64: CodeHighlighter.Language?] = [:]
    private var languageOrder: [Int64] = []

    private var swatches: [Int64: Color?] = [:]
    private var swatchOrder: [Int64] = []

    private var appIcons: [String: NSImage] = [:]

    func rich(for id: Int64) -> AttributedString? {
        richTexts[id]
    }

    func setRich(_ value: AttributedString, for id: Int64) {
        insert(value, key: id, dict: &richTexts, order: &richOrder, limit: 40)
    }

    func highlight(for id: Int64, theme: String) -> CodeText.Result? {
        highlights[HighlightKey(id: id, theme: theme)]
    }

    func setHighlight(_ value: CodeText.Result, for id: Int64, theme: String) {
        insert(value, key: HighlightKey(id: id, theme: theme), dict: &highlights, order: &highlightOrder, limit: 40)
    }

    func markdown(for id: Int64) -> AttributedString? {
        markdownTexts[id]
    }

    func setMarkdown(_ value: AttributedString, for id: Int64) {
        insert(value, key: id, dict: &markdownTexts, order: &markdownOrder, limit: 40)
    }

    func image(for id: Int64) -> NSImage? {
        images[id]
    }

    func setImage(_ value: NSImage, for id: Int64) {
        insert(value, key: id, dict: &images, order: &imageOrder, limit: 30)
    }

    func thumbnail(for id: Int64) -> NSImage? {
        thumbnails[id]
    }

    func setThumbnail(_ value: NSImage, for id: Int64) {
        insert(value, key: id, dict: &thumbnails, order: &thumbnailOrder, limit: 120)
    }

    func language(for item: ClipListItem) -> CodeHighlighter.Language? {
        if let cached = languages[item.id] { return cached }
        let detected = item.content.flatMap { CodeHighlighter.detectLanguage(String($0.prefix(4000))) }
        insert(detected, key: item.id, dict: &languages, order: &languageOrder, limit: 400)
        return detected
    }

    func swatchColor(for item: ClipListItem) -> Color? {
        if let cached = swatches[item.id] { return cached }
        let color: Color? = item.content.flatMap { ColourTransform.parseHex($0) }.flatMap { Color(hex: $0) }
        insert(color, key: item.id, dict: &swatches, order: &swatchOrder, limit: 400)
        return color
    }

    func appIcon(for bundleId: String) -> NSImage {
        if let cached = appIcons[bundleId] { return cached }
        let icon: NSImage
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            icon = NSWorkspace.shared.icon(forFile: url.path)
        } else {
            icon = NSWorkspace.shared.icon(for: .applicationBundle)
        }
        appIcons[bundleId] = icon
        return icon
    }

    public func invalidate(id: Int64) {
        richTexts.removeValue(forKey: id)
        markdownTexts.removeValue(forKey: id)
        images.removeValue(forKey: id)
        thumbnails.removeValue(forKey: id)
        languages.removeValue(forKey: id)
        swatches.removeValue(forKey: id)
        highlights = highlights.filter { $0.key.id != id }
    }

    public func clearAll() {
        richTexts.removeAll()
        richOrder.removeAll()
        highlights.removeAll()
        highlightOrder.removeAll()
        markdownTexts.removeAll()
        markdownOrder.removeAll()
        images.removeAll()
        imageOrder.removeAll()
        thumbnails.removeAll()
        thumbnailOrder.removeAll()
        languages.removeAll()
        languageOrder.removeAll()
        swatches.removeAll()
        swatchOrder.removeAll()
    }

    private func insert<K: Hashable, V>(
        _ value: V, key: K, dict: inout [K: V], order: inout [K], limit: Int
    ) {
        dict[key] = value
        order.removeAll { $0 == key }
        order.append(key)
        while order.count > limit {
            let evicted = order.removeFirst()
            dict.removeValue(forKey: evicted)
        }
    }

    nonisolated static func decodeDownsampledCGImage(from data: Data, maxPixelSize: Int) -> CGImage? {
        let options: [CFString: Any] = [kCGImageSourceShouldCache: false]
        guard let source = CGImageSourceCreateWithData(data as CFData, options as CFDictionary) else {
            return nil
        }
        let thumbOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, thumbOptions as CFDictionary)
    }

    static func makeImage(from cgImage: CGImage?, fallbackData: Data) -> NSImage? {
        if let cgImage {
            return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        }
        return NSImage(data: fallbackData)
    }
}
