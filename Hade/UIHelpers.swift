//
//  UIHelpers.swift
//  Hade
//
//  Arayüz genelinde paylaşılan küçük yardımcılar ve bileşenler.
//

import SwiftUI

extension Color {
    /// Model katmanındaki renk ipucu adlarını gerçek renklere çevirir.
    init(tintName: String) {
        switch tintName {
        case "green": self = .green
        case "orange": self = .orange
        case "blue": self = .blue
        case "purple": self = .purple
        case "red": self = .red
        default: self = .gray
        }
    }
}

/// HTTP metodunu renkli, tek tip bir rozet olarak gösterir.
struct MethodBadge: View {
    let method: HTTPMethod
    var body: some View {
        Text(method.rawValue)
            .font(.system(.caption, design: .monospaced, weight: .bold))
            .foregroundStyle(Color(tintName: method.tintName))
            .frame(width: 52, alignment: .leading)
    }
}
