//
//  ComboBoxField.swift
//  Hade
//
//  Serbest metin kabul eden, öneri listeli düzenlenebilir alan (NSComboBox sarmalayıcısı).
//

import SwiftUI
import AppKit

/// Metin girişine izin veren, aynı zamanda öneri açılır listesi sunan alan.
struct ComboBoxField: NSViewRepresentable {
    @Binding var text: String
    var suggestions: [String]
    var placeholder: String = ""

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSComboBox {
        let combo = NSComboBox()
        combo.isEditable = true
        combo.completes = true
        combo.hasVerticalScroller = true
        combo.numberOfVisibleItems = 12
        combo.addItems(withObjectValues: suggestions)
        combo.placeholderString = placeholder
        combo.delegate = context.coordinator
        combo.font = .systemFont(ofSize: NSFont.systemFontSize)
        combo.stringValue = text
        combo.setContentHuggingPriority(.defaultLow, for: .horizontal)
        combo.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return combo
    }

    func updateNSView(_ combo: NSComboBox, context: Context) {
        // Öneri listesi değiştiyse (ör. header adı değişti) yenile.
        if (combo.objectValues as? [String]) != suggestions {
            combo.removeAllItems()
            combo.addItems(withObjectValues: suggestions)
        }
        if combo.stringValue != text {
            combo.stringValue = text
        }
    }

    final class Coordinator: NSObject, NSComboBoxDelegate {
        let parent: ComboBoxField

        init(_ parent: ComboBoxField) {
            self.parent = parent
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let combo = notification.object as? NSComboBox else { return }
            parent.text = combo.stringValue
        }

        func comboBoxSelectionDidChange(_ notification: Notification) {
            guard let combo = notification.object as? NSComboBox else { return }
            let index = combo.indexOfSelectedItem
            guard index >= 0, index < parent.suggestions.count else { return }
            let value = parent.suggestions[index]
            // Seçim anında stringValue henüz güncellenmediği için sonraki döngüde yaz.
            DispatchQueue.main.async { self.parent.text = value }
        }
    }
}

/// İstek header'ları için yaygın olarak kullanılan standart adlar.
enum HTTPHeaderCatalog {
    static let standard: [String] = [
        "Accept",
        "Accept-Charset",
        "Accept-Encoding",
        "Accept-Language",
        "Authorization",
        "Cache-Control",
        "Connection",
        "Content-Disposition",
        "Content-Encoding",
        "Content-Language",
        "Content-Length",
        "Content-Type",
        "Cookie",
        "Date",
        "ETag",
        "Expect",
        "Forwarded",
        "From",
        "Host",
        "If-Match",
        "If-Modified-Since",
        "If-None-Match",
        "If-Range",
        "If-Unmodified-Since",
        "Origin",
        "Pragma",
        "Prefer",
        "Range",
        "Referer",
        "TE",
        "Upgrade",
        "User-Agent",
        "Via",
        "Warning",
        "X-Api-Key",
        "X-CSRF-Token",
        "X-Forwarded-For",
        "X-Forwarded-Host",
        "X-Forwarded-Proto",
        "X-Requested-With"
    ]

    /// Sık kullanılan içerik türleri (Content-Type / Accept için).
    private static let mediaTypes = [
        "application/json",
        "application/xml",
        "application/x-www-form-urlencoded",
        "multipart/form-data",
        "text/plain",
        "text/html",
        "text/csv",
        "application/octet-stream",
        "application/pdf",
        "image/png",
        "image/jpeg",
        "*/*"
    ]

    /// Verilen header adı için bağlama duyarlı değer önerileri döndürür.
    /// Bilinmeyen header'lar için boş dizi döner (o zaman düz metin kutusu kullanılır).
    static func values(for headerName: String) -> [String] {
        switch headerName.trimmingCharacters(in: .whitespaces).lowercased() {
        case "content-type":
            return mediaTypes
        case "accept":
            return mediaTypes
        case "authorization":
            return ["Bearer ", "Basic "]
        case "accept-encoding", "content-encoding":
            return ["gzip", "deflate", "br", "identity", "gzip, deflate, br"]
        case "accept-charset":
            return ["utf-8", "iso-8859-1"]
        case "accept-language":
            return ["en-US", "en", "tr-TR", "tr", "*"]
        case "cache-control":
            return ["no-cache", "no-store", "max-age=0", "must-revalidate", "public", "private"]
        case "connection":
            return ["keep-alive", "close"]
        case "prefer":
            return ["return=representation", "return=minimal"]
        case "te":
            return ["trailers", "gzip", "deflate"]
        case "x-requested-with":
            return ["XMLHttpRequest"]
        case "expect":
            return ["100-continue"]
        default:
            return []
        }
    }
}
