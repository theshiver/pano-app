import PanoCore
import PanoStore
import PanoTransforms
import PanoUI
import SwiftUI

/// Week 0 exit check: the sandboxed app pastes a hardcoded string into TextEdit.
struct SkeletonView: View {
    @State private var status =
        "Linked: \(PanoCore.moduleName), PanoStore, "
        + "\(PanoTransforms.moduleName), \(PanoUI.moduleName)"

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(status).font(.system(.body, design: .monospaced))
            Button("Paste “hello from Pano” in 3 s") {
                status = "switch to TextEdit…"
                Task {
                    try? await Task.sleep(for: .seconds(3))
                    status = PasteProbe.pasteHello()
                }
            }
            .accessibilityLabel("Paste test string into the frontmost app after three seconds")
        }
        .padding()
        .frame(minWidth: 480)
    }
}
