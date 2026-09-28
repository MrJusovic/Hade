//
//  RequestEditorView.swift
//  Hade
//
//  İstek oluşturma alanı: metod, URL, gönder ve Params/Headers/Body sekmeleri.
//

import SwiftUI

struct RequestEditorView: View {
    @Environment(AppStore.self) private var store

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \RequestCollection.sortIndex, ascending: true)]
    )
    private var collections: FetchedResults<RequestCollection>

    @State private var selectedTab: Tab = .params
    @State private var showingNewCollection = false
    @State private var newCollectionName = ""
    /// URL→tablo senkronunun en son çalıştığı sekme (sekme değişiminde kaybı önlemek için).
    @State private var syncedTabID: RequestTab.ID?

    enum Tab: String, CaseIterable, Identifiable {
        case params = "Parametreler"
        case headers = "Header"
        case body = "Gövde"
        case script = "Script"
        var id: String { rawValue }
    }

    var body: some View {
        VStack(spacing: 0) {
            addressBar
            Divider()
            tabPicker
            Divider()
            tabContent
        }
        .onChange(of: store.draft.urlString) { _, _ in syncItemsFromURL() }
        .onChange(of: store.draft.queryItems) { _, _ in syncURLFromItems() }
        .onAppear {
            syncedTabID = store.activeTabID
            syncURLFromItems()
        }
        .alert("Yeni Koleksiyon", isPresented: $showingNewCollection) {
            TextField("Koleksiyon adı", text: $newCollectionName)
            Button("İptal", role: .cancel) { newCollectionName = "" }
            Button("Oluştur ve Kaydet") {
                let collection = store.addCollection(name: newCollectionName)
                store.saveDraft(to: collection)
                newCollectionName = ""
            }
        }
    }

    // MARK: - URL ↔ Parametreler çift yönlü senkronu

    /// URL'yi taban ve query bileşenlerine ayırır.
    private func splitURL(_ url: String) -> (base: String, query: String?) {
        if let index = url.firstIndex(of: "?") {
            return (String(url[..<index]), String(url[url.index(after: index)...]))
        }
        return (url, nil)
    }

    /// Query string'i anahtar/değer satırlarına ayrıştırır.
    private func parseQuery(_ query: String) -> [KeyValue] {
        query.split(separator: "&", omittingEmptySubsequences: true).map { pair in
            let parts = pair.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            let rawKey = String(parts.first ?? "")
            let rawValue = parts.count > 1 ? String(parts[1]) : ""
            let key = rawKey.removingPercentEncoding ?? rawKey
            let value = rawValue.removingPercentEncoding ?? rawValue
            return KeyValue(key: key, value: value, enabled: true)
        }
    }

    /// Query için güvenli yüzde kodlaması ({{değişken}} süslü parantezlerini korur).
    private func encode(_ text: String) -> String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&=+?#")
        allowed.insert(charactersIn: "{}")
        return text.addingPercentEncoding(withAllowedCharacters: allowed) ?? text
    }

    /// Anahtar/değer çiftlerini (etkinlik hariç) karşılaştırır.
    private func sameKeyValues(_ a: [KeyValue], _ b: [KeyValue]) -> Bool {
        guard a.count == b.count else { return false }
        for (x, y) in zip(a, b) where x.key != y.key || x.value != y.value { return false }
        return true
    }

    /// URL değişince Parametreler tablosunu günceller (devre dışı satırları korur).
    private func syncItemsFromURL() {
        // Sekme değiştiyse (URL değişimi kullanıcı düzenlemesi değil), tabloyu silme;
        // bunun yerine tablo → URL yönünde (kayıpsız) yansıt.
        if store.activeTabID != syncedTabID {
            syncedTabID = store.activeTabID
            syncURLFromItems()
            return
        }

        let (_, query) = splitURL(store.draft.urlString)
        let parsed = query.map(parseQuery) ?? []
        // Sondaki boş satırı karşılaştırmaya katma (gereksiz yeniden kurmayı önler).
        let currentEnabled = store.draft.queryItems.filter { $0.enabled && !$0.isBlank }
        guard !sameKeyValues(parsed, currentEnabled) else { return }

        let disabled = store.draft.queryItems.filter { !$0.enabled }
        // Kimlikleri konuma göre koru (mümkünse).
        var newEnabled: [KeyValue] = []
        for (index, item) in parsed.enumerated() {
            if index < currentEnabled.count {
                var reused = currentEnabled[index]
                reused.key = item.key
                reused.value = item.value
                reused.enabled = true
                newEnabled.append(reused)
            } else {
                newEnabled.append(item)
            }
        }
        store.draft.queryItems = newEnabled + disabled
    }

    /// Parametreler değişince URL'nin query kısmını yeniden yazar.
    private func syncURLFromItems() {
        let (base, _) = splitURL(store.draft.urlString)
        let enabled = store.draft.queryItems.filter {
            $0.enabled && !$0.key.trimmingCharacters(in: .whitespaces).isEmpty
        }
        let query = enabled.map { encode($0.key) + "=" + encode($0.value) }.joined(separator: "&")
        let newURL = query.isEmpty ? base : base + "?" + query
        if newURL != store.draft.urlString {
            store.draft.urlString = newURL
        }
    }

    // MARK: - Adres çubuğu

    private var addressBar: some View {
        @Bindable var store = store
        return VStack(spacing: 8) {
            TextField("İstek adı", text: $store.draft.name)
                .textFieldStyle(.plain)
                .font(.headline)

            HStack(spacing: 8) {
                Picker("", selection: $store.draft.method) {
                    ForEach(HTTPMethod.allCases) { method in
                        Text(method.rawValue).tag(method)
                    }
                }
                .labelsHidden()
                .fixedSize()
                .tint(Color(tintName: store.draft.method.tintName))

                TextField("https://api.ornek.com/kaynak", text: $store.draft.urlString)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .onSubmit { Task { await store.send() } }

                Button {
                    Task { await store.send() }
                } label: {
                    if store.isSending {
                        ProgressView().controlSize(.small)
                    } else {
                        Text("Gönder")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(store.draft.urlString.trimmingCharacters(in: .whitespaces).isEmpty || store.isSending)

                saveMenu
            }
        }
        .padding(12)
    }

    private var saveMenu: some View {
        Menu {
            if store.editingRequestID != nil {
                Button("Değişiklikleri Kaydet") {
                    store.updateEditingRequest()
                }
                Divider()
            }
            if collections.isEmpty {
                Text("Koleksiyon yok")
            } else {
                Menu("Koleksiyona Kaydet") {
                    ForEach(collections) { collection in
                        Button(collection.name ?? "Koleksiyon") {
                            store.saveDraft(to: collection)
                        }
                    }
                }
            }
            Button("Yeni Koleksiyona Kaydet…") {
                showingNewCollection = true
            }
        } label: {
            Image(systemName: "square.and.arrow.down")
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    // MARK: - Sekmeler

    private var tabPicker: some View {
        HStack {
            Picker("", selection: $selectedTab) {
                ForEach(Tab.allCases) { tab in
                    Text(tabTitle(tab)).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private func tabTitle(_ tab: Tab) -> String {
        switch tab {
        case .params:
            let count = store.draft.queryItems.filter { $0.enabled && !$0.key.isEmpty }.count
            return count > 0 ? "\(tab.rawValue) (\(count))" : tab.rawValue
        case .headers:
            let count = store.draft.headers.filter { $0.enabled && !$0.key.isEmpty }.count
            return count > 0 ? "\(tab.rawValue) (\(count))" : tab.rawValue
        case .body:
            return store.draft.bodyKind == .none ? tab.rawValue : "\(tab.rawValue) •"
        case .script:
            return store.draft.scriptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? tab.rawValue : "\(tab.rawValue) •"
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        @Bindable var store = store
        switch selectedTab {
        case .params:
            KeyValueEditorView(items: $store.draft.queryItems, keyPlaceholder: "Parametre", valuePlaceholder: "Değer")
        case .headers:
            headersTab
        case .body:
            bodyEditor
        case .script:
            scriptEditor
        }
    }

    private var headersTab: some View {
        @Bindable var store = store
        return VStack(spacing: 0) {
            if let auth = store.autoAuthorizationPreview(for: store.draft) {
                HStack(spacing: 6) {
                    Image(systemName: "lock.fill").foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Otomatik Authorization gönderilecek")
                            .font(.caption.weight(.semibold))
                        Text(auth)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .textSelection(.enabled)
                    }
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.orange.opacity(0.12))
            }
            KeyValueEditorView(
                items: $store.draft.headers,
                keyPlaceholder: "Header",
                valuePlaceholder: "Değer",
                keySuggestions: HTTPHeaderCatalog.standard,
                valueSuggestions: { HTTPHeaderCatalog.values(for: $0) }
            )
        }
    }

    private var scriptEditor: some View {
        @Bindable var store = store
        return VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Yanıt döndükten sonra çalışan JavaScript")
                    .font(.callout.weight(.semibold))
                Text("Kullanılabilir: response.status · response.body · response.headers · response.json() · setVar(\"anahtar\", değer) · console.log(...)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Örn: setVar(\"token\", response.json().access_token)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)

            Divider()

            CodeEditorView(text: $store.draft.scriptText, highlight: false)
                .padding(4)
        }
    }

    private var bodyEditor: some View {
        @Bindable var store = store
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Picker("Tür", selection: $store.draft.bodyKind) {
                    ForEach(BodyKind.allCases) { kind in
                        Text(kind.label).tag(kind)
                    }
                }
                .fixedSize()

                Spacer()

                if store.draft.bodyKind == .json {
                    Button("JSON Biçimlendir") { beautifyJSON() }
                        .buttonStyle(.borderless)
                }
            }
            .padding(12)

            if store.draft.bodyKind == .none {
                Spacer()
                Text("Bu istek gövde içermiyor.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                Spacer()
            } else if !store.draft.method.allowsBody {
                Spacer()
                Text("\(store.draft.method.rawValue) istekleri gövde taşımaz.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                Spacer()
            } else if store.draft.bodyKind == .form {
                KeyValueEditorView(items: $store.draft.formFields, keyPlaceholder: "Alan", valuePlaceholder: "Değer")
            } else {
                CodeEditorView(text: $store.draft.bodyText, highlight: store.draft.bodyKind == .json)
                    .padding(4)
            }
        }
    }

    private func beautifyJSON() {
        guard let data = store.draft.bodyText.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              let pretty = try? JSONSerialization.data(
                withJSONObject: object,
                options: [.prettyPrinted, .withoutEscapingSlashes]
              ),
              let text = String(data: pretty, encoding: .utf8) else {
            return
        }
        store.draft.bodyText = text
    }
}
