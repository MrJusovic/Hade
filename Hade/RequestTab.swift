//
//  RequestTab.swift
//  Hade
//
//  Açık bir istek sekmesinin durumu (taslak + yanıt + script çıktısı).
//

import Foundation

@MainActor
@Observable
final class RequestTab: Identifiable {
    let id = UUID()

    /// Sekmenin üzerinde çalıştığı istek taslağı.
    var draft: RequestDraft
    /// Düzenlenmekte olan kayıtlı isteğin kimliği (varsa).
    var editingRequestID: UUID?
    /// En son yanıt.
    var response: ResponseResult?
    /// İstek gönderiliyor mu?
    var isSending = false
    /// Bu sekmedeki isteğe ait hata mesajı.
    var errorMessage: String?
    /// Son script çalıştırmasının konsol çıktıları.
    var scriptConsole: [String] = []
    /// Son script çalıştırmasının hata mesajı.
    var scriptError: String?

    init(draft: RequestDraft, editingRequestID: UUID? = nil) {
        self.draft = draft
        self.editingRequestID = editingRequestID
    }

    convenience init() {
        self.init(draft: RequestDraft())
    }

    /// Sekme başlığı için gösterilecek ad.
    var title: String {
        let trimmed = draft.name.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? "İstek" : trimmed
    }
}
