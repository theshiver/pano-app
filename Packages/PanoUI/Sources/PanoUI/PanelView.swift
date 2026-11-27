import AppKit
import PanoStore
import SwiftUI

public struct PanelView: View {
    @State private var model: PanelModel
    @FocusState private var searchFocused: Bool
    @State private var lastClick: (id: Int64, at: Date)?
    @Environment(\.colorScheme) private var scheme

    public init(model: PanelModel) {
        _model = State(initialValue: model)
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                rail
                Divider()
                HStack(spacing: 0) {
                    VStack(spacing: 0) {
                        searchRow
                        Divider()
                        if showQuickFilters {
                            quickFilterStrip
                            Divider()
                        }
                        list
                    }
                    .frame(width: Theme.listWidth)
                    Divider()
                    PreviewPane(model: model)
                        .frame(maxWidth: .infinity)
                }
                .background(Color(nsColor: .windowBackgroundColor).opacity(scheme == .dark ? 0.44 : 0.48))
            }
            Divider()
            StatusBar(
                shown: model.items.count, total: model.totalCount, bytes: model.storageBytes,
                filtered: model.selectedAppId != nil || model.selectedPinboardId != nil
                    || !model.query.trimmingCharacters(in: .whitespaces).isEmpty,
                openSettings: model.openSettings)
        }
        .frame(minWidth: Theme.minWindowWidth, minHeight: Theme.minWindowHeight)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerRadius)
                .strokeBorder(.primary.opacity(scheme == .dark ? 0.14 : 0.10), lineWidth: 0.5)
        )
        .onModifierKeysChanged(mask: .command) { _, new in
            model.commandHeld = new.contains(.command)
        }
        .onAppear {
            model.activate()
            searchFocused = true
        }
        .onChange(of: model.focusRequests) { searchFocused = true }
    }

    private var showQuickFilters: Bool {
        model.query.isEmpty && model.selectedAppId == nil && model.selectedPinboardId == nil
    }

    private var quickFilterStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                quickPill("Code", token: "type:code ")
                quickPill("Images · OCR", token: "type:image ")
                quickPill("Colours", token: "type:colour ")
                quickPill("Pinned", token: "pinned: ")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
        }
    }

    private func quickPill(_ label: String, token: String) -> some View {
        Button {
            model.setQuickFilter(token)
        } label: {
            Text(label)
                .font(Theme.chipFont)
                .foregroundStyle(Theme.secondary(scheme))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.primary.opacity(scheme == .dark ? 0.06 : 0.04))
                )
        }
        .buttonStyle(.plain)
        .focusable(false)
        .pointer()
        .accessibilityLabel("Filter by \(label)")
    }

    private var rail: some View {
        AppRail(model: model)
            .frame(width: Theme.railWidth)
            .frame(maxHeight: .infinity)
            .background(.thinMaterial)
            .gesture(WindowDragGesture())
    }

    private var searchRow: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Theme.secondary(scheme))
                .accessibilityHidden(true)
            TextField("", text: $model.query)
                .textFieldStyle(.plain)
                .font(Theme.searchFont)
                .focused($searchFocused)
                .accessibilityLabel("Search clipboard history")
                .background(alignment: .leading) {
                    if model.query.isEmpty { SearchHints() } else { ghostCompletion }
                }
                .onKeyPress(.tab) { model.acceptCompletion() ? .handled : .ignored }
                .onKeyPress(.downArrow) {
                    model.moveSelection(by: 1); return .handled
                }
                .onKeyPress(.upArrow) {
                    model.moveSelection(by: -1); return .handled
                }
                .onKeyPress(.escape) {
                    if !model.query.isEmpty {
                        model.query = ""
                        return .handled
                    }
                    model.close()
                    return .handled
                }
                .onKeyPress(keys: [.return]) { press in
                    model.pasteSelected(plainText: press.modifiers.contains(.shift))
                    return .handled
                }
                .onKeyPress(characters: .decimalDigits, phases: .down) { press in
                    guard press.modifiers.contains(.command), let n = Int(press.characters), n >= 1, n <= 9 else {
                        return .ignored
                    }
                    if press.modifiers.contains(.shift) {
                        model.toggleSelectedClipInPinboard(rank: n)
                    } else {
                        model.pasteRank(n)
                    }
                    return .handled
                }
                .onKeyPress(characters: CharacterSet(charactersIn: "[]"), phases: .down) { press in
                    guard press.modifiers.contains(.command) else { return .ignored }
                    model.moveAppSelection(by: press.characters == "]" ? 1 : -1)
                    return .handled
                }
                .onKeyPress(characters: CharacterSet(charactersIn: "pP"), phases: .down) { press in
                    guard press.modifiers.contains(.command) else { return .ignored }
                    model.togglePinSelected()
                    return .handled
                }

            if !model.query.isEmpty {
                Button {
                    model.query = ""
                    searchFocused = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.secondary(scheme))
                }
                .buttonStyle(.plain)
                .focusable(false)
                .pointer()
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 13)
        .frame(height: Theme.searchHeight)
    }

    private func click(_ id: Int64) {
        let now = Date()
        if let last = lastClick, last.id == id, now.timeIntervalSince(last.at) < NSEvent.doubleClickInterval {
            lastClick = nil
            model.select(id)
            model.pasteSelected()
            return
        }
        lastClick = (id, now)
        model.select(id)
    }

    @ViewBuilder private var ghostCompletion: some View {
        if let completion = model.completion {
            (Text(model.query).foregroundColor(.clear) + Text(completion).foregroundColor(Theme.secondary(scheme)))
                .font(Theme.searchFont)
                .lineLimit(1)
                .allowsHitTesting(false)
                .accessibilityLabel("Suggestion: \(model.query)\(completion). Press Tab to accept.")
        }
    }

    private var list: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if model.items.isEmpty {
                    emptyState
                }
                LazyVStack(spacing: 2) {
                    ForEach(Array(model.items.enumerated()), id: \.element.id) { index, item in
                        ClipRow(
                            item: item,
                            model: model,
                            isSelected: item.id == model.selectedId,
                            quickRank: model.commandHeld && index < 9 ? index + 1 : nil,
                            showLanguage: model.highlightCode
                        )
                        .id(item.id)
                        .draggable(ClipDrag(item))
                        .onTapGesture { click(item.id) }
                        .contextMenu { rowContextMenu(for: item) }
                        .pointer()
                    }
                }
                .padding(6)
            }
            .onChange(of: model.selectedId) { _, new in
                if let new { proxy.scrollTo(new, anchor: .center) }
            }
        }
    }

    @ViewBuilder private func rowContextMenu(for item: ClipListItem) -> some View {
        let verb = model.autoPasteActive ? "Paste" : "Copy"
        Button(verb) { model.copyItem(item.id, plainText: false) }
        Button("\(verb) as Plain Text") { model.copyItem(item.id, plainText: true) }
        Divider()
        Button(item.isPinned ? "Unpin" : "Pin") { model.togglePin(item.id) }
        if !model.pinboards.isEmpty {
            Menu("Add to Pinboard") {
                ForEach(model.pinboards) { board in
                    Button(board.name) { model.addClip(item.id, toPinboard: board.id) }
                }
            }
        }
        Divider()
        Button("Delete", role: .destructive) { model.deleteItem(item.id) }
    }

    @ViewBuilder private var emptyState: some View {
        let searching =
            !model.query.trimmingCharacters(in: .whitespaces).isEmpty || model.selectedAppId != nil
        let board = model.pinboards.first { $0.id == model.selectedPinboardId }
        VStack(spacing: 6) {
            Image(
                systemName: board != nil ? (board?.icon ?? "pin") : searching ? "magnifyingglass" : "doc.on.clipboard"
            )
            .font(.system(size: 22))
            .foregroundStyle(Theme.secondary(scheme))
            Text(board.map { "Nothing on “\($0.name)” yet" } ?? (searching ? "No results" : "No clipboard history yet"))
                .font(Theme.rowContent)
                .foregroundStyle(Theme.secondary(scheme))
            if board != nil {
                Text(
                    "Drag a clip here, or press ⌘⇧\(model.pinboards.firstIndex { $0.id == board?.id }.map { $0 + 1 } ?? 1)."
                )
                .font(Theme.rowMeta)
                .foregroundStyle(Theme.secondary(scheme))
            } else if !searching {
                Text("Copy something and it appears here.")
                    .font(Theme.rowMeta)
                    .foregroundStyle(Theme.secondary(scheme))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
        .accessibilityElement(children: .combine)
    }
}
