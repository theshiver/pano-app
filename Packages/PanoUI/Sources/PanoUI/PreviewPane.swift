import PanoStore
import PanoTransforms
import SwiftUI

/// The right-hand preview: a header with the source, time and transform chips; the body (raw text,
/// a transformed value, or a colour swatch + format list); and the keyboard-hint footer.
struct PreviewPane: View {
    @Bindable var model: PanelModel
    @Environment(\.colorScheme) private var scheme
    /// The last highlight result and the clip/theme it belongs to; computed off the main actor.
    @State private var highlighted: (id: Int64, theme: String, result: CodeText.Result)?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let item = model.selectedItem {
                header(item)
                Divider()
                body(for: item)
                Spacer(minLength: 0)
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
            Text(item.sourceName ?? item.sourceBundleId ?? "Unknown")
                .font(Theme.rowMeta)
                .foregroundStyle(Theme.secondary(scheme))
            Text(ClipRow.age(item.lastSeenAt))
                .font(Theme.rowMeta)
                .foregroundStyle(Theme.secondary(scheme))
            Spacer()
            ForEach(model.availableTransforms, id: \.id) { transform in
                chip(transform)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: Theme.searchHeight)  // same height as the search row so the dividers line up
        .contentShape(Rectangle())
        .gesture(WindowDragGesture())  // header doubles as the panel's title-bar drag handle
    }

    private func chip(_ transform: any Transform) -> some View {
        let active = model.activeTransformId == transform.id
        return Button {
            model.toggleTransform(transform.id)
        } label: {
            Text(transform.title)
                .font(Theme.chipFont)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(active ? Theme.accent : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(active ? Color.clear : Theme.secondary(scheme).opacity(0.4), lineWidth: 1)
                )
                .foregroundStyle(active ? Color.white : Theme.secondary(scheme))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(transform.title) transform")
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
            let code =
                wantsCode && highlighted?.id == item.id && highlighted?.theme == model.syntaxTheme
                ? highlighted?.result : nil
            let preview = CodeText.preview(model.transformOutput?.text ?? item.content ?? "—")
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    Group {
                        if let code {
                            Text(code.text)
                        } else if let html = model.transformOutput?.html, let rich = RichPreview.attributed(html: html)
                        {
                            Text(rich)
                        } else {
                            Text(preview.text)
                                .font(Theme.previewBody)
                        }
                    }
                    .textSelection(.enabled)
                    if preview.cutLines > 0 {
                        Text("… \(preview.cutLines) more lines — the whole clip pastes")
                            .font(Theme.rowMeta)
                            .foregroundStyle(Theme.secondary(scheme))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
            }
            .background(code?.background ?? .clear)
            .transition(.opacity)
            .id(model.activeTransformId ?? "raw")
            .animation(.easeInOut(duration: 0.09), value: model.activeTransformId)
            .task(id: "\(item.id)-\(model.syntaxTheme)-\(wantsCode)") {
                guard wantsCode, let content = item.content else { return }
                let (text, _) = CodeText.preview(content)
                let language = CodeHighlighter.detectLanguage(String(text.prefix(4000)))
                let theme = model.syntaxTheme
                guard let result = await CodeText.shared.highlight(text, language: language, theme: theme) else {
                    return
                }
                if !Task.isCancelled { highlighted = (item.id, theme, result) }
            }
        }
    }

    private func wantsHighlight(_ item: ClipListItem) -> Bool {
        model.highlightCode && model.activeTransform == nil && item.kind == .code && item.content != nil
    }

    /// A colour's formats: a large swatch, then one pasteable row per representation.
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
                            .frame(width: 56, alignment: .leading)
                        Text(format.value).font(Theme.previewBody).textSelection(.enabled)
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Paste \(format.label) \(format.value)")
            }
        }
        .padding(12)
    }

    private func centeredNote(_ text: String) -> some View {
        Text(text)
            .font(Theme.previewBody)
            .foregroundStyle(Theme.secondary(scheme))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
    }

    private var footer: some View {
        HStack {
            Text(hint)
                .font(Theme.chipFont)
                .foregroundStyle(Theme.secondary(scheme))
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private var hint: String {
        let item = model.selectedItem
        if (item?.kind == .image || item?.kind == .file), let ocr = item?.ocrText, !ocr.isEmpty {
            return "⏎ paste image · ⇧⏎ paste text · ⌘P pin"
        }
        if model.activeTransform != nil {
            return "⏎ paste transformed · ⇧⏎ raw · ⌘P pin"
        }
        if model.selectedPinboardId != nil {
            return "⏎ paste · ⇧⏎ raw · ⌘P pin · ⌘⌫ remove from board"
        }
        return "⏎ paste · ⇧⏎ raw · ⌘P pin · ⌘⌫ delete"
    }
}

/// Shows the actual image immediately (loaded async from the store); any OCR text runs in the
/// background and appears underneath for reference, without replacing the visual preview.
private struct ImagePreview: View {
    let item: ClipListItem
    let model: PanelModel
    @State private var imageData: Data?
    @State private var loaded = false
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Group {
                if let imageData, let nsImage = NSImage(data: imageData) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .accessibilityLabel("Copied image")
                } else if loaded {
                    // A file with no image preview: show its name/path instead of a spinner.
                    Text(item.content ?? "File")
                        .font(Theme.previewBody)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ProgressView().frame(maxWidth: .infinity, minHeight: 120)
                }
            }
            .padding(12)

            if imageData != nil, let ocr = item.ocrText ?? item.content, !ocr.isEmpty {
                Divider()
                ScrollView {
                    Text(ocr)
                        .font(Theme.rowMeta)
                        .foregroundStyle(Theme.secondary(scheme))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                }
                .frame(maxHeight: 140)
            }
        }
        .task(id: item.id) {
            loaded = false
            imageData = await model.imageData(for: item.id)
            loaded = true
        }
    }
}

extension Color {
    /// Builds a Color from a #RRGGBB or #RRGGBBAA string (preview swatch, pinboard colours).
    init?(hex: String) {
        var s = hex
        s.removeFirst()  // '#'
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
