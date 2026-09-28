//
//  CodeEditorView.swift
//  Hade
//
//  JSON sözdizimi renklendirmesi yapan, düzenlenebilir bir NSTextView sarmalayıcısı.
//

import SwiftUI
import AppKit

/// Yazdıkça JSON'ı renklendiren düzenlenebilir kod editörü.
struct CodeEditorView: NSViewRepresentable {
    @Binding var text: String
    /// Renklendirme uygulansın mı? (yalnızca JSON gövdesi için)
    var highlight: Bool = true

    private static let font = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        guard let textView = scrollView.documentView as? NSTextView else { return scrollView }

        textView.delegate = context.coordinator
        textView.font = Self.font
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isGrammarCheckingEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.allowsUndo = true
        textView.textContainerInset = NSSize(width: 6, height: 8)
        textView.backgroundColor = .textBackgroundColor
        textView.string = text
        applyHighlight(textView)

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        // Dışarıdan gelen değişiklikleri (ör. "JSON Biçimlendir") yansıt.
        if textView.string != text {
            let selected = textView.selectedRanges
            textView.string = text
            applyHighlight(textView)
            textView.selectedRanges = selected
        }
    }

    fileprivate func applyHighlight(_ textView: NSTextView) {
        guard let storage = textView.textStorage else { return }
        if highlight {
            JSONHighlighter.apply(to: storage, font: Self.font)
        } else {
            storage.setAttributes(
                [.font: Self.font, .foregroundColor: NSColor.labelColor],
                range: NSRange(location: 0, length: storage.length)
            )
        }
        textView.typingAttributes = [.font: Self.font, .foregroundColor: NSColor.labelColor]
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        let parent: CodeEditorView

        init(_ parent: CodeEditorView) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
            parent.applyHighlight(textView)
        }
    }
}
