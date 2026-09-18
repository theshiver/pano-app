import AppKit
import PanoStore
import SwiftUI

/// The panel content: the source-app rail, the search field over the result list, and the live
/// preview, with the status bar underneath. Keyboard-first (docs/05-design.md): the search field
/// owns first responder and drives selection with the arrow keys; ⏎ pastes, esc closes.
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
                VStack(spacing: 0) {
                    searchRow
                    Divider()
                    list
                }
                .frame(width: Theme.listWidth)
                Divider()
                PreviewPane(model: model)
                    .frame(maxWidth: .infinity)
            }
            Divider()
            StatusBar(
                shown: model.items.count, total: model.totalCount, bytes: model.storageBytes,
                filtered: model.selectedAppId != nil || model.selectedPinboardId != nil
                    || !model.query.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .frame(width: Theme.windowWidth, height: Theme.windowHeight)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
        .onModifierKeysChanged(mask: .command) { _, new in
            model.commandHeld = new.contains(.command)
        }
        .onAppear {
            model.activate()
            searchFocused = true
        }
    }

    private var rail: some View {
        AppRail(model: model)
            .frame(width: Theme.railWidth)
            .frame(maxHeight: .infinity)
            .background(.thinMaterial)
            .gesture(WindowDragGesture())  // empty rail space drags the panel
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
                .onKeyPress(.rightArrow) { model.acceptCompletion() ? .handled : .ignored }
                .onKeyPress(.downArrow) {
                    model.moveSelection(by: 1); return .handled
                }
                .onKeyPress(.upArrow) {
                    model.moveSelection(by: -1); return .handled
                }
                .onKeyPress(.escape) {
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
                        model.toggleSelectedClipInPinboard(rank: n)  // ⌘⇧n: toggle on the nth pinboard
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
        }
        .padding(.horizontal, 13)
        .frame(height: Theme.searchHeight)
    }

    /// A click selects at once; a second click on the same row within the double-click interval
    /// pastes. Done by hand because `onTapGesture(count: 2)` makes SwiftUI hold every single click
    /// until the double-click window has passed, which read as lag.
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

    /// The completion drawn behind the field: the typed text invisibly (to take up its width), then
    /// the suggested rest in secondary colour, so it reads as one line.
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
                            isSelected: item.id == model.selectedId,
                            quickRank: model.commandHeld && index < 9 ? index + 1 : nil,
                            showLanguage: model.highlightCode
                        )
                        .id(item.id)
                        .draggable(ClipDrag(item))
                        .onTapGesture { click(item.id) }
                    }
                }
                .padding(6)
            }
            .onChange(of: model.selectedId) { _, new in
                if let new { proxy.scrollTo(new, anchor: .center) }
            }
        }
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
