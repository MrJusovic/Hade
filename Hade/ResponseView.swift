//
//  ResponseView.swift
//  Hade
//
//  Sunucu yanıtını (status, süre, boyut, header, body) gösteren panel.
//

import SwiftUI

struct ResponseView: View {
    let response: ResponseResult?
    let isSending: Bool
    let errorMessage: String?
    var scriptConsole: [String] = []
    var scriptError: String? = nil

    @State private var selectedTab: Tab = .body
    @State private var prettyPrint = true

    enum Tab: String, CaseIterable, Identifiable {
        case body = "Gövde"
        case headers = "Header"
        case console = "Konsol"
        var id: String { rawValue }
    }

    private var hasScriptOutput: Bool {
        !scriptConsole.isEmpty || scriptError != nil
    }

    private var availableTabs: [Tab] {
        hasScriptOutput ? [.body, .headers, .console] : [.body, .headers]
    }

    /// Seçili sekme kullanılabilir değilse Gövde'ye düşen güvenli seçim.
    private var tabSelection: Binding<Tab> {
        Binding(
            get: { availableTabs.contains(selectedTab) ? selectedTab : .body },
            set: { selectedTab = $0 }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isSending {
                centered {
                    ProgressView("İstek gönderiliyor…")
                }
            } else if let errorMessage {
                centered {
                    ContentUnavailableView {
                        Label("İstek başarısız", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(errorMessage)
                    }
                }
            } else if let response {
                statusBar(response)
                Divider()
                tabPicker
                Divider()
                content(for: response)
            } else {
                centered {
                    ContentUnavailableView(
                        "Henüz yanıt yok",
                        systemImage: "arrow.down.circle",
                        description: Text("Bir istek gönderin, yanıt burada görünecek.")
                    )
                }
            }
        }
    }

    // MARK: - Alt bileşenler

    private func statusBar(_ response: ResponseResult) -> some View {
        HStack(spacing: 16) {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color(tintName: response.statusTintName))
                    .frame(width: 8, height: 8)
                Text("\(response.statusCode)")
                    .fontWeight(.bold)
                Text(response.statusText)
                    .foregroundStyle(.secondary)
            }
            Label(Format.duration(response.durationMs), systemImage: "clock")
                .foregroundStyle(.secondary)
            Label(Format.size(response.byteCount), systemImage: "shippingbox")
                .foregroundStyle(.secondary)
            Spacer()
        }
        .font(.callout)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var tabPicker: some View {
        HStack {
            Picker("", selection: tabSelection) {
                ForEach(availableTabs) { tab in
                    if tab == .console, scriptError != nil {
                        Label(tab.rawValue, systemImage: "exclamationmark.triangle.fill").tag(tab)
                    } else {
                        Text(tab.rawValue).tag(tab)
                    }
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()

            Spacer()

            if tabSelection.wrappedValue == .body, let response, response.isJSON {
                Toggle("Biçimlendir", isOn: $prettyPrint)
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }

            if tabSelection.wrappedValue == .body, let response {
                Button {
                    copyToClipboard(prettyPrint ? response.prettyBody : response.bodyString)
                } label: {
                    Label("Kopyala", systemImage: "doc.on.doc")
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private func content(for response: ResponseResult) -> some View {
        switch tabSelection.wrappedValue {
        case .body:
            let raw = prettyPrint ? response.prettyBody : response.bodyString
            ScrollView([.vertical, .horizontal]) {
                Group {
                    if response.isJSON {
                        Text(JSONHighlighter.attributedString(for: raw))
                    } else {
                        Text(raw).font(.system(.body, design: .monospaced))
                    }
                }
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
            }
        case .headers:
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(response.headers.enumerated()), id: \.offset) { _, pair in
                        HStack(alignment: .top, spacing: 12) {
                            Text(pair.0)
                                .fontWeight(.medium)
                                .frame(width: 200, alignment: .leading)
                            Text(pair.1)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                            Spacer()
                        }
                        .font(.system(.callout, design: .monospaced))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        Divider()
                    }
                }
            }
        case .console:
            consoleContent
        }
    }

    private var consoleContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                if let scriptError {
                    Label(scriptError, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                }
                ForEach(Array(scriptConsole.enumerated()), id: \.offset) { _, line in
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(line)
                            .textSelection(.enabled)
                    }
                }
                if scriptConsole.isEmpty && scriptError == nil {
                    Text("Script çıktısı yok.")
                        .foregroundStyle(.secondary)
                }
            }
            .font(.system(.callout, design: .monospaced))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
        }
    }

    private func centered<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack {
            Spacer()
            content()
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
