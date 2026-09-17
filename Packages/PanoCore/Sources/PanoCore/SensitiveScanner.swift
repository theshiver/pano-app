import Foundation
import PanoStore

/// Detects secrets in a copied string so they get the short retention rule and are masked
/// in the list (docs/03-data-model.md). Runs over the text form only, before the row is written.
///
/// A heuristic on purpose: a false positive means "this expired sooner than you expected", a
/// false negative means a key sits in the database for a month. The trade favours over-detection.
public enum SensitiveScanner {
    public static func classify(_ text: String?) -> Clip.Sensitivity {
        guard let text, !text.isEmpty else { return .none }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if looksLikeAPIKey(trimmed) || looksLikeJWT(trimmed) {
            return .secret
        }
        if containsPaymentCard(text) || containsIBAN(text) {
            return .financial
        }
        return .none
    }

    // MARK: API keys

    /// Known prefixes plus a length/charset sanity check, so a sentence starting with "sk-"
    /// does not trip it. The token must be a single run of key-ish characters.
    static func looksLikeAPIKey(_ text: String) -> Bool {
        guard isSingleToken(text) else { return false }
        let prefixes = [
            "sk-", "sk_", "pk_", "rk_", "ghp_", "gho_", "ghu_", "ghs_", "github_pat_",
            "xoxb-", "xoxp-", "xoxa-", "AKIA", "ASIA", "AIza", "ya29.", "glpat-",
        ]
        for prefix in prefixes where text.hasPrefix(prefix) {
            let body = text.dropFirst(prefix.count)
            let ok = body.count >= 12 && body.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "-" }
            if ok { return true }
        }
        return false
    }

    // MARK: JWT

    /// Three base64url segments separated by dots, the first decoding to a JSON object with "alg".
    static func looksLikeJWT(_ text: String) -> Bool {
        guard isSingleToken(text) else { return false }
        let parts = text.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3, parts.allSatisfy({ !$0.isEmpty }) else { return false }
        guard let header = base64urlDecode(String(parts[0])),
            let json = try? JSONSerialization.jsonObject(with: header) as? [String: Any]
        else { return false }
        return json["alg"] != nil
    }

    // MARK: Payment cards

    /// 13–19 digit run (spaces and dashes allowed as separators) that passes the Luhn check.
    static func containsPaymentCard(_ text: String) -> Bool {
        for token in tokens(in: text) {
            let digits = token.filter(\.isNumber)
            guard token.allSatisfy({ $0.isNumber || $0 == "-" || $0 == " " }),
                (13...19).contains(digits.count)
            else { continue }
            if luhnValid(digits) { return true }
        }
        return false
    }

    static func luhnValid(_ digits: String) -> Bool {
        var sum = 0
        for (offset, char) in digits.reversed().enumerated() {
            guard let d = char.wholeNumberValue else { return false }
            if offset.isMultiple(of: 2) {
                sum += d
            } else {
                let doubled = d * 2
                sum += doubled > 9 ? doubled - 9 : doubled
            }
        }
        return sum % 10 == 0
    }

    // MARK: IBAN

    /// Two-letter country code, a length matching the country's table, and a mod-97 checksum of 1.
    static func containsIBAN(_ text: String) -> Bool {
        for raw in tokens(in: text) {
            let token = raw.uppercased().filter { $0.isLetter || $0.isNumber }
            guard token.count >= 15, token.count <= 34 else { continue }
            let country = String(token.prefix(2))
            guard let expected = ibanLengths[country], token.count == expected else { continue }
            if ibanMod97(token) == 1 { return true }
        }
        return false
    }

    static func ibanMod97(_ iban: String) -> Int {
        let rearranged = iban.dropFirst(4) + iban.prefix(4)
        var remainder = 0
        for char in rearranged {
            let value: Int
            if let digit = char.wholeNumberValue, char.isNumber {
                value = digit
            } else if let ascii = char.asciiValue, char.isLetter {
                value = Int(ascii - 65) + 10  // A=10 … Z=35
            } else {
                return -1
            }
            for d in "\(value)" { remainder = (remainder * 10 + (d.wholeNumberValue ?? 0)) % 97 }
        }
        return remainder
    }

    private static let ibanLengths: [String: Int] = [
        "TR": 26, "DE": 22, "GB": 22, "FR": 27, "NL": 18, "ES": 24, "IT": 27,
        "CH": 21, "BE": 16, "AT": 20, "IE": 22, "PT": 25, "PL": 28, "SE": 24,
    ]

    // MARK: helpers

    private static func isSingleToken(_ text: String) -> Bool {
        !text.isEmpty && !text.contains(where: \.isWhitespace)
    }

    private static func tokens(in text: String) -> [String] {
        text.split(whereSeparator: { $0 == "\n" || $0 == "\t" || $0 == "," || $0 == ";" })
            .map { $0.trimmingCharacters(in: .whitespaces) }
    }

    private static func base64urlDecode(_ s: String) -> Data? {
        var b = s.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while b.count % 4 != 0 { b += "=" }
        return Data(base64Encoded: b)
    }
}
