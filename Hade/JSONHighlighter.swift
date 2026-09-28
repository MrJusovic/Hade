//
//  JSONHighlighter.swift
//  Hade
//
//  JSON metnini sözdizimine göre renklendiren paylaşımlı yardımcı.
//

import AppKit

/// JSON tokenlarını renklendiren basit bir sözdizimi vurgulayıcı.
enum JSONHighlighter {

    /// Token türleri ve karşılık gelen renkler.
    private enum Token {
        case key, string, number, keyword

        var color: NSColor {
            switch self {
            case .key: return .systemPurple
            case .string: return .systemGreen
            case .number: return .systemBlue
            case .keyword: return .systemOrange
            }
        }
    }

    /// Dize (anahtar/değer), sayı ve true/false/null yakalayan düzenli ifade.
    private static let regex: NSRegularExpression = {
        let pattern = #""(?:\\.|[^"\\])*"|-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?|\b(?:true|false|null)\b"#
        // swiftlint:disable:next force_try
        return try! NSRegularExpression(pattern: pattern)
    }()

    /// Metindeki tüm tokenları (aralık + tür) döndürür.
    private static func tokens(in text: String) -> [(NSRange, Token)] {
        let ns = text as NSString
        let full = NSRange(location: 0, length: ns.length)
        var result: [(NSRange, Token)] = []

        for match in regex.matches(in: text, range: full) {
            let range = match.range
            let value = ns.substring(with: range)

            if value.hasPrefix("\"") {
                // Dizeden sonra ':' geliyorsa bu bir anahtardır.
                var i = range.location + range.length
                while i < ns.length, let scalar = ns.substring(with: NSRange(location: i, length: 1)).unicodeScalars.first,
                      CharacterSet.whitespacesAndNewlines.contains(scalar) {
                    i += 1
                }
                let isKey = i < ns.length && ns.substring(with: NSRange(location: i, length: 1)) == ":"
                result.append((range, isKey ? .key : .string))
            } else if value == "true" || value == "false" || value == "null" {
                result.append((range, .keyword))
            } else {
                result.append((range, .number))
            }
        }
        return result
    }

    /// Bir NSTextStorage'a renklendirmeyi uygular (düzenlenebilir editör için).
    static func apply(to storage: NSTextStorage, font: NSFont) {
        let full = NSRange(location: 0, length: storage.length)
        storage.beginEditing()
        storage.setAttributes([.font: font, .foregroundColor: NSColor.labelColor], range: full)
        for (range, token) in tokens(in: storage.string) {
            storage.addAttribute(.foregroundColor, value: token.color, range: range)
        }
        storage.endEditing()
    }

    /// Varsayılan tek aralıklı fontla renklendirilmiş AttributedString (salt-okunur).
    static func attributedString(for text: String) -> AttributedString {
        attributedString(for: text, font: .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular))
    }

    /// Salt-okunur görünüm için renklendirilmiş AttributedString üretir.
    static func attributedString(for text: String, font: NSFont) -> AttributedString {
        let mutable = NSMutableAttributedString(
            string: text,
            attributes: [.font: font, .foregroundColor: NSColor.labelColor]
        )
        for (range, token) in tokens(in: text) {
            mutable.addAttribute(.foregroundColor, value: token.color, range: range)
        }
        return AttributedString(mutable)
    }
}
