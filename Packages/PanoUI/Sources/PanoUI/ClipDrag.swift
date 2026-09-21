import PanoStore
import SwiftUI
import UniformTypeIdentifiers

/// What a dragged row carries. Inside the panel (pinboards) the clip id travels under `.panoClip`.
/// Into other apps it exports, by kind: a file clip as its URL (Finder copies it), an image clip as
/// PNG/TIFF/JPEG bytes, everything else as text. Representations are ordered by priority.
struct ClipDrag: Codable, Transferable {
    var id: Int64
    var kind: Clip.Kind
    var text: String

    /// Loads a clip's stored representations on demand; wired to the store by `PanelModel`.
    nonisolated(unsafe) static var payload: @Sendable (Int64) async -> [(uti: String, data: Data)] = { _ in [] }

    init(_ item: ClipListItem) {
        id = item.id
        kind = item.kind
        text = item.isMasked ? "" : (item.content ?? "")
    }

    static var transferRepresentation: some TransferRepresentation {
        // The stored public.file-url bytes go out as-is; ProxyRepresentation's async exporter is deprecated.
        DataRepresentation(exportedContentType: .fileURL) { drag in try await imageBytes(drag.id, "public.file-url") }
            .exportingCondition { $0.kind == .file }
        DataRepresentation(exportedContentType: .png) { drag in try await imageBytes(drag.id, "public.png") }
            .exportingCondition { $0.kind == .image }
        DataRepresentation(exportedContentType: .tiff) { drag in try await imageBytes(drag.id, "public.tiff") }
            .exportingCondition { $0.kind == .image }
        DataRepresentation(exportedContentType: .jpeg) { drag in try await imageBytes(drag.id, "public.jpeg") }
            .exportingCondition { $0.kind == .image }
        ProxyRepresentation(exporting: \.text)
            .exportingCondition { $0.kind != .image && $0.kind != .file }
        CodableRepresentation(contentType: .panoClip)  // last: internal only, pinboards match it by type
    }

    private static func imageBytes(_ id: Int64, _ uti: String) async throws -> Data {  // any stored representation
        guard let data = await payload(id).first(where: { $0.uti == uti })?.data else {
            throw CocoaError(.fileNoSuchFile)
        }
        return data
    }
}

extension UTType {
    static let panoClip = UTType(exportedAs: "com.cancetin.pano.clip")
}
