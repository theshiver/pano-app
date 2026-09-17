import PanoStore
import SwiftUI

/// The panel content: a slim rail placeholder, the search field over the result list, and the
/// live preview, with the status bar underneath. Keyboard-first (docs/05-design.md): the search
/// field owns first responder and drives selection with the arrow keys; ⏎ pastes, esc closes.
///
/// The source-app rail's filtering is week 7; it renders as a plain material column for now.
public struct PanelView: View {
    @State private var model: PanelModel
    @FocusState private var searchFocused: Bool
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
                PreviewPane(item: selectedItem)
                    .frame(maxWidth: .infinity)
            }
            Divider()
            StatusBar(itemCount: model.items.count)
        }
        .frame(width: Theme.windowWidth, height: Theme.windowHeight)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
        .onAppear {
            model.activate()
            searchFocused = true
        }
    }

    private var rail: some View {
        VStack { Spacer() }
            .frame(width: Theme.railWidth)
            .frame(maxHeight: .infinity)
            .background(.thinMaterial)
    }

    private var searchRow: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Theme.secondary(scheme))
                .accessibilityHidden(true)
            TextField("Search", text: $model.query)
                .textFieldStyle(.plain)
                .font(Theme.searchFont)
                .focused($searchFocused)
                .accessibilityLabel("Search clipboard history")
                .onKeyPress(.downArrow) {
                    model.moveSelection(by: 1); return .handled
                }
                .onKeyPress(.upArrow) {
                    model.moveSelection(by: -1); return .handled
                }
                .onKeyPress(.return) {
                    model.pasteSelected(); return .handled
                }
                .onKeyPress(.escape) {
                    model.close(); return .handled
                }
        }
        .padding(.horizontal, 13)
        .frame(height: Theme.searchHeight)
    }

    private var list: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(model.items) { item in
                        ClipRow(item: item, isSelected: item.id == model.selectedId)
                            .id(item.id)
                            .onTapGesture {
                                model.select(item.id)
                                model.pasteSelected()
                            }
                    }
                }
                .padding(6)
            }
            .onChange(of: model.selectedId) { _, new in
                if let new { proxy.scrollTo(new, anchor: .center) }
            }
        }
    }

    private var selectedItem: ClipListItem? {
        model.items.first { $0.id == model.selectedId }
    }
}
