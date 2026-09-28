//
//  CollectionSettingsView.swift
//  Hade
//
//  Koleksiyona özel ayarlar: ad, kaynak URL ve değişkenler ({{baseUrl}} vb.).
//

import SwiftUI

struct CollectionSettingsView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let collection: RequestCollection

    @State private var name = ""
    @State private var sourceURL = ""
    @State private var variables: [KeyValue] = []
    @State private var loaded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Koleksiyon Ayarları")
                    .font(.title2.weight(.semibold))
                Spacer()
                Button("Bitti") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(16)

            Divider()

            Form {
                Section("Genel") {
                    TextField("Ad", text: $name)
                        .onChange(of: name) { _, value in store.rename(collection, to: value) }
                    TextField("Kaynak URL (Swagger/OpenAPI)", text: $sourceURL, prompt: Text("https://…/openapi.json"))
                        .font(.system(.body, design: .monospaced))
                        .onChange(of: sourceURL) { _, value in store.setSourceURL(value, for: collection) }
                }
            }
            .formStyle(.grouped)
            .frame(maxHeight: 150)

            VStack(alignment: .leading, spacing: 2) {
                Text("Değişkenler")
                    .font(.headline)
                Text("İstek URL, header ve gövdesinde {{anahtar}} olarak kullanın. Örn: {{baseUrl}}")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Tip “Authorization” olan değişkenin değeri, kimlik doğrulama gerektiren uçlara otomatik Authorization header'ı olarak eklenir. Örn: Bearer {{token}}")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 4)

            KeyValueEditorView(items: $variables, keyPlaceholder: "Değişken", valuePlaceholder: "Değer", showTypes: true)
                .onChange(of: variables) { _, value in store.setVariables(value, for: collection) }
        }
        .frame(width: 560, height: 480)
        .onAppear {
            guard !loaded else { return }
            name = collection.name ?? ""
            sourceURL = collection.sourceURL ?? ""
            variables = AppStore.decodeKeyValues(collection.variablesJSON)
            loaded = true
        }
    }
}
