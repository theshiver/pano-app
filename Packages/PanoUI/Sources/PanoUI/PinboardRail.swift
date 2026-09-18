import PanoStore
import SwiftUI

/// The bottom half of the rail: one coloured circle per pinboard, a "+" to create one. A circle is
/// a drop target for rows, a filter when tapped, and has a context menu to delete the board.
/// Keyboard: ⌘⇧1–9 toggles the selected clip on the nth board.
struct PinboardRail: View {
    let model: PanelModel
    @State private var creating = false
    @State private var dropTarget: Int64?

    static let colours = ["#2A6DF0", "#E5484D", "#F59E0B", "#16A34A", "#8B5CF6", "#0891B2", "#DB2777", "#6E6E73"]
    static let icons = ["pin", "briefcase", "star", "bolt", "heart", "folder", "tag", "book"]

    var body: some View {
        VStack(spacing: 8) {
            Divider().padding(.horizontal, 12)
            ForEach(model.pinboards) { board in
                boardButton(board)
            }
            Button {
                creating = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 30, height: 30)
                    .overlay(Circle().strokeBorder(.quaternary, lineWidth: 1))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .focusable(false)  // the search field owns keyboard focus; rail buttons must never take it
            .pointer()
            .help("New pinboard")
            .accessibilityLabel("New pinboard")
            .popover(isPresented: $creating) {
                NewPinboardForm { name, colour, icon in
                    model.createPinboard(name: name, colour: colour, icon: icon)
                    creating = false
                }
            }
        }
    }

    private func boardButton(_ board: Pinboard) -> some View {
        let selected = model.selectedPinboardId == board.id
        let targeted = dropTarget == board.id
        let ring: Color = selected || targeted ? Theme.accent : Color.clear
        let fill: Color = Color(hex: board.colour) ?? Color.gray
        return Button {
            model.selectPinboard(board.id)
        } label: {
            Image(systemName: board.icon ?? "pin")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.white)
                .frame(width: 30, height: 30)
                .background(fill, in: Circle())
                .padding(2)
                .background(.background, in: Circle())
                .padding(2)
                .background(ring, in: Circle())
                .scaleEffect(targeted ? 1.12 : 1)
                .animation(.easeOut(duration: 0.12), value: targeted)
        }
        .buttonStyle(.plain)
        .focusable(false)  // the search field owns keyboard focus; rail buttons must never take it
        .pointer()
        .help(board.name)
        .accessibilityLabel("Pinboard \(board.name)")
        .accessibilityAddTraits(selected ? [.isSelected] : [])
        .contextMenu {
            Button("Delete “\(board.name)”", role: .destructive) { model.deletePinboard(board.id) }
        }
        .dropDestination(for: ClipDrag.self) { drags, _ in
            for drag in drags { model.addClip(drag.id, toPinboard: board.id) }
            return !drags.isEmpty
        } isTargeted: { over in
            dropTarget = over ? board.id : (dropTarget == board.id ? nil : dropTarget)
        }
    }
}

private struct NewPinboardForm: View {
    let create: (String, String, String) -> Void
    @State private var name = ""
    @State private var colour = PinboardRail.colours[0]
    @State private var icon = PinboardRail.icons[0]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Name", text: $name)
                .textFieldStyle(.roundedBorder)
                .onSubmit(submit)
            HStack(spacing: 6) {
                ForEach(PinboardRail.colours, id: \.self) { c in
                    Circle()
                        .fill(Color(hex: c) ?? .gray)
                        .frame(width: 18, height: 18)
                        .overlay(Circle().strokeBorder(.primary, lineWidth: colour == c ? 2 : 0))
                        .onTapGesture { colour = c }
                        .accessibilityLabel("Colour \(c)")
                        .accessibilityAddTraits(colour == c ? [.isSelected] : [])
                }
            }
            HStack(spacing: 6) {
                ForEach(PinboardRail.icons, id: \.self) { i in
                    Image(systemName: i)
                        .frame(width: 22, height: 22)
                        .background(
                            icon == i ? Theme.accent.opacity(0.2) : Color.clear, in: RoundedRectangle(cornerRadius: 5)
                        )
                        .onTapGesture { icon = i }
                        .accessibilityLabel("Icon \(i)")
                        .accessibilityAddTraits(icon == i ? [.isSelected] : [])
                }
            }
            Button("Create", action: submit)
                .keyboardShortcut(.defaultAction)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(12)
        .frame(width: 240)
    }

    private func submit() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        create(trimmed, colour, icon)
    }
}
