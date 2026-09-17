import SwiftUI

/// Colour and metric tokens from docs/05-design.md (direction B — Material). Both themes are
/// first class; where a semantic system colour exists it is preferred, per the doc.
public enum Theme {
    public static let accent = Color(red: 0x2A / 255, green: 0x6D / 255, blue: 0xF0 / 255)

    // Geometry (points)
    public static let windowWidth: CGFloat = 760
    public static let windowHeight: CGFloat = 440
    public static let cornerRadius: CGFloat = 13
    public static let railWidth: CGFloat = 56
    public static let listWidth: CGFloat = 300
    public static let searchHeight: CGFloat = 44
    public static let statusHeight: CGFloat = 24
    public static let rowCorner: CGFloat = 7
    public static let dotSize: CGFloat = 18

    // Type
    public static let rowContent = Font.system(size: 12)
    public static let rowMeta = Font.system(size: 9.5, design: .monospaced)
    public static let searchFont = Font.system(size: 13)
    public static let previewBody = Font.system(size: 10.5, design: .monospaced)
    public static let chipFont = Font.system(size: 9.5, design: .monospaced)

    static func secondary(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(white: 0.63) : Color(red: 0x6E / 255, green: 0x6E / 255, blue: 0x73 / 255)
    }
}
