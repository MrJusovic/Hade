//
//  ImportView.swift
//  Hade
//
//  Swagger/OpenAPI dokümanından koleksiyon içe aktarma penceresi.
//

import SwiftUI
import UniformTypeIdentifiers

struct ImportView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    enum Mode: String, CaseIterable, Identifiable {
        case url = "URL'den"
        case file = "Dosyadan"
        var id: String { rawValue }
    }

    @State private var mode: Mode = .url
    @State private var urlString = ""
    @State private var showFileImporter = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Swagger / OpenAPI İçe Aktar")
                .font(.title2.weight(.semibold))

            Text("OpenAPI 3 veya Swagger 2 (JSON) dokümanını koleksiyon olarak ekleyin. URL'den içe aktarılan koleksiyonlar daha sonra kaynağından güncellenebilir.")
                .font(.callout)
                .foregroundStyle(.secondary)

            Picker("", selection: $mode) {
                ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            switch mode {
            case .url:
                urlSection
            case .file:
                fileSection
            }

            if let error = store.importError {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.callout)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            HStack {
                Spacer()
                Button("Kapat") { dismiss() }
            }
        }
        .padding(20)
        .frame(width: 460, height: 340)
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.json, UTType(filenameExtension: "yaml") ?? .json, .data],
            allowsMultipleSelection: false
        ) { result in
            handleFileSelection(result)
        }
    }

    private var urlSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("https://api.ornek.com/openapi.json", text: $urlString)
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))
                .onSubmit { importFromURL() }

            HStack {
                Spacer()
                Button {
                    importFromURL()
                } label: {
                    if store.isImporting {
                        ProgressView().controlSize(.small)
                    } else {
                        Text("İçe Aktar")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(urlString.trimmingCharacters(in: .whitespaces).isEmpty || store.isImporting)
            }
        }
    }

    private var fileSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Yerel bir JSON dosyası seçin.")
                .font(.callout)
                .foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button("Dosya Seç…") { showFileImporter = true }
                    .buttonStyle(.borderedProminent)
                    .disabled(store.isImporting)
            }
        }
    }

    private func importFromURL() {
        let value = urlString
        Task {
            await store.importCollection(fromURLString: value)
            if store.importError == nil { dismiss() }
        }
    }

    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            do {
                let data = try Data(contentsOf: url)
                try store.importCollection(from: data, sourceURL: nil)
                store.importError = nil
                dismiss()
            } catch let error as OpenAPIImportError {
                store.importError = error.errorDescription
            } catch {
                store.importError = "Dosya okunamadı: \(error.localizedDescription)"
            }
        case .failure(let error):
            store.importError = error.localizedDescription
        }
    }
}
