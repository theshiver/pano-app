import PanoStore
import SwiftUI
import UniformTypeIdentifiers

/// What a dragged row carries: the clip id for drops inside the panel (pinboards) and the text
/// for drops into other apps. Image/file drag-out is the next step.
struct ClipDrag: Codable, Transferable {
    var id: Int64
    var text: String

    init(_ item: ClipListItem) {
        id = item.id
        text = item.isMasked ? "" : (item.content ?? "")
    }

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .panoClip)
        ProxyRepresentation(exporting: \.text)
    }
}

extension UTType {
    static let panoClip = UTType(exportedAs: "com.cancetin.pano.clip")
}
