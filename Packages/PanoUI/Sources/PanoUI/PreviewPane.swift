import PanoStore
import PanoTransforms
import SwiftUI

struct PreviewPane: View {
    @Bindable var model: PanelModel
    @Environment(\.colorScheme) private var scheme
    @State private var highlighted: (id: Int64, theme: String, result: CodeText.Result)?
    @State private var rich: (id: Int64, text: AttributedString)?
    @State private var markdownRendered: (key: String, text: AttributedString)?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let item = model.selectedItem {
                header(item)
                Divider()
                body(for: item)
                Spacer(minLength: 0)
                contextualTip(for: item)
                footer
            } else {
                Spacer()
                Text("No selection")
                    .font(Theme.rowContent)
                    .foregroundStyle(Theme.secondary(scheme))
                    .frame(maxWidth: .infinity)
                Spacer()
            }
        }
    }

    private func header(_ item: ClipListItem) -> some View {
        HStack(spacing: 6) {
            Text(
                [item.sourceName ?? item.sourceBundleId ?? "Unknown", ClipRow.age(item.lastSeenAt), kindLabel(item)]
                    .joined(separator: " · ")
            )
            .font(Theme.rowMeta)
            .foregroundStyle(Theme.secondary(scheme))
            .lineLimit(1)
            .truncationMode(.tail)
            Spacer(minLength: 6)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 5) {
                    if item.kind == .code {
                        chip("Highlight", active: model.highlightCode, label: "Syntax highlighting") {
                            model.toggleHighlight()
                        }
                    }
                    if model.hasImage(item) {
                        chip("OCR", active: model.ocrEnabled, label: "Read text in images") { model.toggleOCR() }
                    }
                    ForEach(model.availableTransforms, id: \.id) { transform in
                        chip(
                            transform.title, active: model.activeTransformId == transform.id,
                            label: "\(transform.title) transform"
                        ) {
                            model.toggleTransform(transform.id)
                        }
                    }
                }
            }
            .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 12)
        .frame(height: Theme.searchHeight)
        .contentShape(Rectangle())
        .gesture(WindowDragGesture())
    }

    private func kindLabel(_ item: ClipListItem) -> String {
        if item.kind == .code, model.highlightCode, let language = PreviewCache.shared.language(for: item) {
            return "code · \(language.rawValue)"
        }
        return item.kind == .richtext ? "rich text" : item.kind.rawValue
    }

    private func chip(_ title: String, active: Bool, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Theme.chipFont)
                .padding(.horizontal, 7)
                .padding(.vertical, 2.5)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(active ? Theme.accent : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(active ? Color.clear : Theme.secondary(scheme).opacity(0.35), lineWidth: 1)
                )
                .foregroundStyle(active ? Color.white : Theme.secondary(scheme))
        }
        .buttonStyle(.plain)
        .focusable(false)
        .pointer()
        .accessibilityLabel(label)
        .accessibilityAddTraits(active ? [.isSelected] : [])
    }

    @ViewBuilder private func body(for item: ClipListItem) -> some View {
        if item.isMasked {
            centeredNote("Not stored — this looked like a secret.")
        } else if item.kind == .image || item.kind == .file {
            ImagePreview(item: item, model: model)
        } else if let output = model.transformOutput, !output.formats.isEmpty {
            colourFormats(output.formats)
        } else {
            let wantsCode = wantsHighlight(item)
            let cachedCode = wantsCode ? PreviewCache.shared.highlight(for: item.id, theme: model.syntaxTheme) : nil
            let code =
                cachedCode
                ?? (wantsCode && highlighted?.id == item.id && highlighted?.theme == model.syntaxTheme
                    ? highlighted?.result : nil)

            let cachedRich =
                (item.kind == .richtext && model.activeTransform == nil)
                ? PreviewCache.shared.rich(for: item.id) : nil
            let resolvedRich =
                cachedRich
                ?? (item.kind == .richtext && model.activeTransform == nil && rich?.id == item.id
                    ? rich?.text : nil)

            let mdKey = "\(item.id)-\(model.activeTransformId ?? "")"
            let cachedMarkdown = (model.transformOutput?.html != nil) ? PreviewCache.shared.markdown(for: item.id) : nil
            let resolvedMarkdown = cachedMarkdown ?? (markdownRendered?.key == mdKey ? markdownRendered?.text : nil)

            let preview = CodeText.preview(model.transformOutput?.text ?? item.content ?? "—")

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    Group {
                        if let code {
                            Text(code.text)
                        } else if model.transformOutput?.html != nil {
                            if let resolvedMarkdown {
                                Text(resolvedMarkdown)
                            } else {
                                Text(preview.text).font(Theme.previewBody)
                            }
                        } else if item.kind == .richtext, model.activeTransform == nil {
                            if let resolvedRich {
                                Text(resolvedRich)
                            } else {
                                ProgressView()
                                    .controlSize(.small)
                                    .frame(maxWidth: .infinity, minHeight: 80, alignment: .center)
                            }
                        } else {
                            Text(preview.text)
                                .font(Theme.previewBody)
                        }
                    }
                    .textSelection(.enabled)
                    if preview.cutLines > 0 {
                        Text("… \(preview.cutLines) more lines — the whole clip is copied")
                            .font(Theme.rowMeta)
                            .foregroundStyle(Theme.secondary(scheme))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
            }
            .background(code?.background ?? .clear)
            .id(model.activeTransformId ?? "raw")
            .task(id: "rich-\(item.id)") {
                guard item.kind == .richtext, PreviewCache.shared.rich(for: item.id) == nil else { return }
                let payload = await model.payload(for: item.id)
                guard !Task.isCancelled else { return }
                if let text = RichPreview.attributed(payload: payload), !Task.isCancelled {
                    PreviewCache.shared.setRich(text, for: item.id)
                    rich = (item.id, text)
                }
            }
            .task(id: "md-\(mdKey)") {
                guard let html = model.transformOutput?.html else { return }
                if let cached = PreviewCache.shared.markdown(for: item.id) {
                    markdownRendered = (mdKey, cached)
                    return
                }
                if let rendered = RichPreview.attributed(html: html), !Task.isCancelled {
                    PreviewCache.shared.setMarkdown(rendered, for: item.id)
                    markdownRendered = (mdKey, rendered)
                }
            }
            .task(id: "\(item.id)-\(model.syntaxTheme)-\(wantsCode)") {
                guard wantsCode, let content = item.content else { return }
                let theme = model.syntaxTheme
                if PreviewCache.shared.highlight(for: item.id, theme: theme) != nil { return }
                guard await settled() else { return }
                let (text, _) = CodeText.preview(content)
                let language = PreviewCache.shared.language(for: item)
                guard let result = await CodeText.shared.highlight(text, language: language, theme: theme) else {
                    return
                }
                if !Task.isCancelled {
                    PreviewCache.shared.setHighlight(result, for: item.id, theme: theme)
                    highlighted = (item.id, theme, result)
                }
            }
            .task(id: "prefetch-\(item.id)-\(model.syntaxTheme)") {
                try? await Task.sleep(for: .milliseconds(70))
                guard !Task.isCancelled else { return }
                for neighbor in model.neighborItems(around: item.id) {
                    guard !Task.isCancelled else { return }
                    if neighbor.kind == .richtext, PreviewCache.shared.rich(for: neighbor.id) == nil {
                        let payload = await model.payload(for: neighbor.id)
                        if let text = RichPreview.attributed(payload: payload), !Task.isCancelled {
                            PreviewCache.shared.setRich(text, for: neighbor.id)
                        }
                    } else if model.highlightCode, neighbor.kind == .code, let content = neighbor.content,
                        PreviewCache.shared.highlight(for: neighbor.id, theme: model.syntaxTheme) == nil
                    {
                        let (text, _) = CodeText.preview(content)
                        let language = PreviewCache.shared.language(for: neighbor)
                        if let res = await CodeText.shared.highlight(
                            text, language: language, theme: model.syntaxTheme
                        ), !Task.isCancelled {
                            PreviewCache.shared.setHighlight(res, for: neighbor.id, theme: model.syntaxTheme)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder private func contextualTip(for item: ClipListItem) -> some View {
        if let prefs = model.prefs {
            if model.hasImage(item), let ocr = item.ocrText, !ocr.isEmpty, !prefs.ocrTipDismissed {
                tipBanner("Text indexed on-device — search any word inside this image, or press ⇧⏎ to copy text.") {
                    prefs.ocrTipDismissed = true
                }
            } else if model.activeTransform == nil,
                model.availableTransforms.contains(where: { ["json", "jwt", "b64"].contains($0.id) }),
                !prefs.transformTipDismissed
            {
                tipBanner("Tip: type json, jwt, or b64 in the search field to transform on the fly.") {
                    prefs.transformTipDismissed = true
                }
            }
        }
    }

    private func tipBanner(_ message: String, onDismiss: @escaping () -> Void) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "lightbulb")
                .font(.system(size: 11))
                .foregroundStyle(Theme.brandAccent)
            Text(message)
                .font(Theme.rowMeta)
                .foregroundStyle(Theme.secondary(scheme))
            Spacer(minLength: 4)
            Button("Got it", action: onDismiss)
                .font(Theme.rowMeta)
                .buttonStyle(.plain)
                .foregroundStyle(Theme.accent)
                .pointer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.quaternary.opacity(0.45))
    }

    private func wantsHighlight(_ item: ClipListItem) -> Bool {
        model.highlightCode && model.activeTransform == nil && item.kind == .code && item.content != nil
    }

    private func colourFormats(_ formats: [TransformOutput.Format]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let hex = formats.first(where: { $0.label == "HEX" })?.value {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(hex: hex) ?? .gray)
                    .frame(height: 64)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.separator))
                    .accessibilityLabel("Colour swatch \(hex)")
            }
            ForEach(formats) { format in
                Button {
                    model.pasteText(format.value)
                } label: {
                    HStack {
                        Text(format.label).font(Theme.rowMeta).foregroundStyle(Theme.secondary(scheme))
                            .frame(width: 68, alignment: .leading)
                        Text(format.value).font(Theme.previewBody).textSelection(.enabled)
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .pointer()
                .accessibilityLabel("Copy \(format.label) \(format.value)")
            }
        }
        .padding(14)
    }

    private func centeredNote(_ text: String) -> some View {
        Text(text)
            .font(Theme.previewBody)
            .foregroundStyle(Theme.secondary(scheme))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
    }

    private var footer: some View {
        HStack {
            Text(hint)
                .font(Theme.chipFont)
                .foregroundStyle(Theme.secondary(scheme))
            Spacer()
            if !model.autoPasteActive {
                Text("then ⌘V in your app")
                    .font(Theme.chipFont)
                    .foregroundStyle(Theme.secondary(scheme))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
    }

    private static let settleDelay = Duration.milliseconds(45)

    private func settled() async -> Bool {
        try? await Task.sleep(for: Self.settleDelay)
        return !Task.isCancelled
    }

    private var verb: String { model.autoPasteActive ? "paste" : "copy" }

    private var hint: String {
        let item = model.selectedItem
        if (item?.kind == .image || item?.kind == .file), let ocr = item?.ocrText, !ocr.isEmpty {
            return "⏎ \(verb) image · ⇧⏎ \(verb) text · ⌘P pin"
        }
        if model.activeTransform != nil {
            return "⏎ \(verb) transformed · ⇧⏎ raw · ⌘P pin"
        }
        if model.selectedPinboardId != nil {
            return "⏎ \(verb) · ⇧⏎ raw · ⌘P pin · ⌘⌫ remove from board"
        }
        return "⏎ \(verb) · ⇧⏎ raw · ⌘P pin · ⌘⌫ delete"
    }
}

private struct ImagePreview: View {
    let item: ClipListItem
    let model: PanelModel
    @State private var image: NSImage?
    @State private var loaded = false
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Group {
                    if let resolved = PreviewCache.shared.image(for: item.id) ?? image {
                        Image(nsImage: resolved)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity, maxHeight: 280)
                            .accessibilityLabel("Copied image")
                    } else if loaded {
                        Text(item.content ?? "File")
                            .font(Theme.previewBody)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        ProgressView()
                            .controlSize(.small)
                            .frame(maxWidth: .infinity, minHeight: 120)
                    }
                }
                .padding(14)

                if loaded || PreviewCache.shared.image(for: item.id) != nil, model.ocrEnabled,
                    let ocr = item.ocrText ?? item.content, !ocr.isEmpty
                {
                    Divider()
                    Text(ocr)
                        .font(Theme.rowMeta)
                        .foregroundStyle(Theme.secondary(scheme))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                }
            }
        }
        .task(id: item.id) {
            if let cached = PreviewCache.shared.image(for: item.id) {
                image = cached
                loaded = true
                return
            }
            loaded = false
            image = nil
            if let data = await model.imageData(for: item.id) {
                let cgImage = await Task.detached(priority: .userInitiated) {
                    PreviewCache.decodeDownsampledCGImage(from: data, maxPixelSize: 1600)
                }.value
                if !Task.isCancelled,
                    let decoded = PreviewCache.makeImage(from: cgImage, fallbackData: data)
                {
                    PreviewCache.shared.setImage(decoded, for: item.id)
                    image = decoded
                }
            }
            if !Task.isCancelled { loaded = true }
        }
    }
}

extension Color {
    init?(hex: String) {
        var s = hex
        s.removeFirst()
        guard s.allSatisfy(\.isHexDigit), s.count == 6 || s.count == 8 else { return nil }
        func v(_ start: Int) -> Double {
            let i = s.index(s.startIndex, offsetBy: start)
            let j = s.index(i, offsetBy: 2)
            return Double(Int(s[i..<j], radix: 16) ?? 0) / 255
        }
        self.init(
            .sRGB, red: v(0), green: v(2), blue: v(4),
            opacity: s.count == 8 ? v(6) : 1
        )
    }
}
