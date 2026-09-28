//
//  KeyValueEditorView.swift
//  Hade
//
//  Header, query parametresi ve form alanları için yeniden kullanılabilir tablo.
//

import SwiftUI

/// Anahtar/değer satırlarını düzenlemek için basit bir tablo görünümü.
struct KeyValueEditorView: View {
    @Binding var items: [KeyValue]
    var keyPlaceholder: String = "Anahtar"
    var valuePlaceholder: String = "Değer"
    /// Verilirse anahtar alanı, bu önerileri sunan düzenlenebilir bir açılır liste olur.
    var keySuggestions: [String]? = nil
    /// Verilirse, satırın anahtarına göre değer alanına bağlama duyarlı öneriler sunar.
    var valueSuggestions: ((String) -> [String])? = nil
    /// Tip sütununu göster (koleksiyon değişkenleri için).
    var showTypes: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach($items) { $item in
                        row(for: $item)
                        Divider()
                    }
                }
            }

            HStack {
                Button {
                    if items.last?.isBlank != true { items.append(KeyValue()) }
                } label: {
                    Label("Satır Ekle", systemImage: "plus")
                }
                .buttonStyle(.borderless)
                Spacer()
            }
            .padding(8)
        }
        // Tab ile son hücreden yeni satıra geçebilmek için sonda her zaman boş bir satır tut.
        .onAppear { ensureTrailingRow() }
        .onChange(of: items) { _, _ in ensureTrailingRow() }
    }

    /// Listenin sonunda düzenlenmeye hazır boş bir satır bulunmasını garanti eder.
    private func ensureTrailingRow() {
        if items.last?.isBlank != true {
            items.append(KeyValue())
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Spacer().frame(width: 22)
            Text(keyPlaceholder)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(valuePlaceholder)
                .frame(maxWidth: .infinity, alignment: .leading)
            if showTypes {
                Text("Tip").frame(width: 130, alignment: .leading)
            }
            Spacer().frame(width: 24)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(.quaternary.opacity(0.5))
    }

    private func row(for item: Binding<KeyValue>) -> some View {
        HStack(spacing: 8) {
            Toggle("", isOn: item.enabled)
                .labelsHidden()
                .toggleStyle(.checkbox)
                .frame(width: 22)

            if let suggestions = keySuggestions {
                ComboBoxField(text: item.key, suggestions: suggestions, placeholder: keyPlaceholder)
                    .frame(maxWidth: .infinity)
            } else {
                TextField(keyPlaceholder, text: item.key)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: .infinity)
            }

            let valueOptions = valueSuggestions?(item.wrappedValue.key) ?? []
            if item.wrappedValue.type == .secret {
                SecureField(valuePlaceholder, text: item.value)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: .infinity)
            } else if !valueOptions.isEmpty {
                ComboBoxField(text: item.value, suggestions: valueOptions, placeholder: valuePlaceholder)
                    .frame(maxWidth: .infinity)
            } else {
                TextField(valuePlaceholder, text: item.value)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: .infinity)
            }

            if showTypes {
                Picker("", selection: item.type) {
                    ForEach(KeyValueType.allCases) { type in
                        Text(type.label).tag(type)
                    }
                }
                .labelsHidden()
                .frame(width: 130)
            }

            Button {
                items.removeAll { $0.id == item.wrappedValue.id }
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .frame(width: 24)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .opacity(item.wrappedValue.enabled ? 1 : 0.5)
    }
}
