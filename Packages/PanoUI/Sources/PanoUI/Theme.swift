import SwiftUI

public enum Theme {
    public static let accent = Color(red: 0x2A / 255, green: 0x6D / 255, blue: 0xF0 / 255)
    public static let brandAccent = Color(red: 0xD4 / 255, green: 0x82 / 255, blue: 0x0A / 255)
    public static let warmSand = Color(red: 0xF2 / 255, green: 0xE2 / 255, blue: 0xD4 / 255)
    public static let slateInk = Color(red: 0x2E / 255, green: 0x31 / 255, blue: 0x3A / 255)

    // Geometry (points)
    public static let windowWidth: CGFloat = 820
    public static let windowHeight: CGFloat = 480
    public static let minWindowWidth: CGFloat = 720
    public static let minWindowHeight: CGFloat = 380
    public static let cornerRadius: CGFloat = 13
    public static let railWidth: CGFloat = 56
    public static let listWidth: CGFloat = 310
    public static let searchHeight: CGFloat = 44
    public static let statusHeight: CGFloat = 26
    public static let rowCorner: CGFloat = 7
    public static let dotSize: CGFloat = 22

    // Type
    public static let rowContent = Font.system(size: 12.5)
    public static let rowMeta = Font.system(size: 10.5, design: .monospaced)
    public static let searchFont = Font.system(size: 13.5)
    public static let previewBody = Font.system(size: 11.5, design: .monospaced)
    public static let chipFont = Font.system(size: 10.5, design: .monospaced)

    static func secondary(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(white: 0.64) : Color(red: 0x66 / 255, green: 0x66 / 255, blue: 0x6C / 255)
    }
}
