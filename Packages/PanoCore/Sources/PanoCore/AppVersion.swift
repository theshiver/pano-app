import Foundation

public struct AppVersion: Comparable, Hashable, Sendable, CustomStringConvertible {
    public let components: [Int]

    public init?(_ raw: String) {
        var trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("v") || trimmed.hasPrefix("V") {
            trimmed.removeFirst()
        }
        if let plus = trimmed.firstIndex(of: "+") {
            trimmed = String(trimmed[..<plus])
        }
        guard !trimmed.isEmpty, !trimmed.contains("-") else { return nil }

        let parts = trimmed.split(separator: ".", omittingEmptySubsequences: false)
        guard !parts.isEmpty else { return nil }

        var parsed: [Int] = []
        parsed.reserveCapacity(parts.count)
        for part in parts {
            guard !part.isEmpty, part.allSatisfy(\.isASCII), part.allSatisfy(\.isNumber),
                let value = Int(part), value >= 0
            else {
                return nil
            }
            parsed.append(value)
        }
        self.components = parsed
    }

    public var description: String {
        components.map(String.init).joined(separator: ".")
    }

    private var normalizedComponents: [Int] {
        var normalized = components
        while normalized.count > 1, normalized.last == 0 {
            normalized.removeLast()
        }
        return normalized
    }

    public static func == (lhs: AppVersion, rhs: AppVersion) -> Bool {
        lhs.normalizedComponents == rhs.normalizedComponents
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(normalizedComponents)
    }

    public static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        let count = max(lhs.components.count, rhs.components.count)
        for index in 0..<count {
            let left = index < lhs.components.count ? lhs.components[index] : 0
            let right = index < rhs.components.count ? rhs.components[index] : 0
            if left != right {
                return left < right
            }
        }
        return false
    }
}
