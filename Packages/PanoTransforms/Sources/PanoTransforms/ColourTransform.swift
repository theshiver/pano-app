import Foundation

/// Converts a colour between formats — the feature no competitor has (docs/01-product.md). Parses
/// hex, `rgb()/rgba()`, `hsl()/hsla()`; emits hex, rgb, hsl and a SwiftUI `Color`. Each format is a
/// separately pasteable row. Tailwind class mapping is a follow-up (it needs the full palette table).
public struct ColourTransform: Transform {
    public let id = "colour"
    public let title = "Colour"
    public init() {}

    public func applies(to text: String) -> Bool {
        Colour(parsing: text) != nil
    }

    public func apply(_ input: String) throws -> TransformOutput {
        guard let colour = Colour(parsing: input) else { throw TransformError.notApplicable }
        let formats = [
            TransformOutput.Format("HEX", colour.hex),
            TransformOutput.Format("RGB", colour.rgb),
            TransformOutput.Format("HSL", colour.hsl),
            TransformOutput.Format("SwiftUI", colour.swiftUI),
        ]
        return TransformOutput(colour.hex, formats: formats)
    }
}

/// RGB in 0...255 with a 0...1 alpha. Internal to the colour transform.
struct Colour: Equatable {
    var r: Int
    var g: Int
    var b: Int
    var a: Double

    init?(parsing text: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if t.hasPrefix("#"), let c = Self.parseHex(t) { self = c; return }
        if t.hasPrefix("rgb"), let c = Self.parseRGB(t) { self = c; return }
        if t.hasPrefix("hsl"), let c = Self.parseHSL(t) { self = c; return }
        return nil
    }

    init(r: Int, g: Int, b: Int, a: Double = 1) {
        self.r = r
        self.g = g
        self.b = b
        self.a = a
    }

    // MARK: Parsing

    private static func parseHex(_ t: String) -> Colour? {
        let hex = String(t.dropFirst())
        guard hex.allSatisfy(\.isHexDigit) else { return nil }
        func byte(_ s: Substring) -> Int { Int(s, radix: 16) ?? 0 }
        let chars = Array(hex)
        switch chars.count {
        case 3:
            return Colour(
                r: byte("\(chars[0])\(chars[0])"), g: byte("\(chars[1])\(chars[1])"), b: byte("\(chars[2])\(chars[2])"))
        case 4:
            let a = Double(byte("\(chars[3])\(chars[3])")) / 255
            return Colour(
                r: byte("\(chars[0])\(chars[0])"), g: byte("\(chars[1])\(chars[1])"), b: byte("\(chars[2])\(chars[2])"),
                a: a)
        case 6:
            return Colour(
                r: byte(hex.prefix(2)), g: byte(hex.dropFirst(2).prefix(2)), b: byte(hex.dropFirst(4).prefix(2)))
        case 8:
            let a = Double(byte(hex.dropFirst(6).prefix(2))) / 255
            return Colour(
                r: byte(hex.prefix(2)), g: byte(hex.dropFirst(2).prefix(2)), b: byte(hex.dropFirst(4).prefix(2)), a: a)
        default:
            return nil
        }
    }

    private static func numbers(in t: String) -> [Double] {
        let inside = t.drop { $0 != "(" }.dropFirst().prefix { $0 != ")" }
        return inside.split(separator: ",").compactMap {
            Double($0.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "%", with: ""))
        }
    }

    private static func parseRGB(_ t: String) -> Colour? {
        let n = numbers(in: t)
        guard n.count >= 3 else { return nil }
        return Colour(
            r: clampByte(n[0]), g: clampByte(n[1]), b: clampByte(n[2]), a: n.count >= 4 ? min(max(n[3], 0), 1) : 1)
    }

    private static func parseHSL(_ t: String) -> Colour? {
        let n = numbers(in: t)
        guard n.count >= 3 else { return nil }
        let (r, g, b) = hslToRGB(h: n[0], s: n[1] / 100, l: n[2] / 100)
        return Colour(r: r, g: g, b: b, a: n.count >= 4 ? min(max(n[3], 0), 1) : 1)
    }

    private static func clampByte(_ v: Double) -> Int { min(max(Int(v.rounded()), 0), 255) }

    // MARK: Output

    var hex: String {
        let base = String(format: "#%02X%02X%02X", r, g, b)
        return a < 1 ? base + String(format: "%02X", Int((a * 255).rounded())) : base
    }

    var rgb: String {
        a < 1 ? "rgba(\(r), \(g), \(b), \(trimmed(a)))" : "rgb(\(r), \(g), \(b))"
    }

    var hsl: String {
        let (h, s, l) = Self.rgbToHSL(r: r, g: g, b: b)
        let hue = Int(h.rounded())
        let sat = Int((s * 100).rounded())
        let lit = Int((l * 100).rounded())
        return a < 1 ? "hsla(\(hue), \(sat)%, \(lit)%, \(trimmed(a)))" : "hsl(\(hue), \(sat)%, \(lit)%)"
    }

    var swiftUI: String {
        func f(_ v: Int) -> String { trimmed(Double(v) / 255) }
        let base = "Color(red: \(f(r)), green: \(f(g)), blue: \(f(b))"
        return a < 1 ? base + ", opacity: \(trimmed(a)))" : base + ")"
    }

    private func trimmed(_ v: Double) -> String {
        String(format: "%.3f", v).replacingOccurrences(of: "0+$", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\\.$", with: "", options: .regularExpression)
    }

    // MARK: Colour maths

    private static func hslToRGB(h: Double, s: Double, l: Double) -> (Int, Int, Int) {
        let c = (1 - abs(2 * l - 1)) * s
        let hp = (h.truncatingRemainder(dividingBy: 360) / 60)
        let x = c * (1 - abs(hp.truncatingRemainder(dividingBy: 2) - 1))
        let m = l - c / 2
        let (r1, g1, b1): (Double, Double, Double)
        switch hp {
        case 0..<1: (r1, g1, b1) = (c, x, 0)
        case 1..<2: (r1, g1, b1) = (x, c, 0)
        case 2..<3: (r1, g1, b1) = (0, c, x)
        case 3..<4: (r1, g1, b1) = (0, x, c)
        case 4..<5: (r1, g1, b1) = (x, 0, c)
        default: (r1, g1, b1) = (c, 0, x)
        }
        return (Int(((r1 + m) * 255).rounded()), Int(((g1 + m) * 255).rounded()), Int(((b1 + m) * 255).rounded()))
    }

    static func rgbToHSL(r: Int, g: Int, b: Int) -> (Double, Double, Double) {
        let rf = Double(r) / 255, gf = Double(g) / 255, bf = Double(b) / 255
        let maxV = max(rf, gf, bf), minV = min(rf, gf, bf)
        let l = (maxV + minV) / 2
        guard maxV != minV else { return (0, 0, l) }
        let d = maxV - minV
        let s = l > 0.5 ? d / (2 - maxV - minV) : d / (maxV + minV)
        var h: Double
        switch maxV {
        case rf: h = (gf - bf) / d + (gf < bf ? 6 : 0)
        case gf: h = (bf - rf) / d + 2
        default: h = (rf - gf) / d + 4
        }
        return (h * 60, s, l)
    }
}
