//
//  SidebarView.swift
//  Hade
//
//  Koleksiyonlar, kayıtlı istekler ve geçmişi listeleyen; arama ve
//  kategori gruplama destekleyen kenar çubuğu.
//

import SwiftUI

extension RequestCollection {
    /// İçindeki istekleri sıra numarasına göre sıralı döndürür.
    var sortedRequests: [SavedRequest] {
        let set = requests as? Set<SavedRequest> ?? []
        return set.sorted { ($0.sortIndex, $0.name ?? "") < ($1.sortIndex, $1.name ?? "") }
    }
}

struct SidebarView: View {
    @Environment(AppStore.self) private var store

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \RequestCollection.sortIndex, ascending: true)]
    )
    private var collections: FetchedResults<RequestCollection>

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \HistoryEntry.timestamp, ascending: false)]
    )
    private var history: FetchedResults<HistoryEntry>

    @State private var searchText = ""
    @State private var expandedCollections: Set<UUID> = []
    @State private var expandedCategories: Set<String> = []
    @State private var renamingCollection: RequestCollection?
    @State private var renameText = ""
    @State private var settingsCollection: RequestCollection?
    @State private var showingClearHistory = false

    private var searching: Bool {
        !searchText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            searchField
            Divider()
            list
        }
        .sheet(item: $settingsCollection) { collection in
            CollectionSettingsView(collection: collection)
                .environment(store)
        }
        .alert("Koleksiyonu Yeniden Adlandır", isPresented: Binding(
            get: { renamingCollection != nil },
            set: { if !$0 { renamingCollection = nil } }
        )) {
            TextField("Ad", text: $renameText)
            Button("İptal", role: .cancel) { renamingCollection = nil }
            Button("Kaydet") {
                if let collection = renamingCollection {
                    store.rename(collection, to: renameText)
                }
                renamingCollection = nil
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Ara", text: $searchText)
                .textFieldStyle(.plain)
            if searching {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    private var list: some View {
        List {
            Section("Koleksiyonlar") {
                let visible = collections.filter(collectionMatches)
                if visible.isEmpty {
                    Text(searching ? "Eşleşme yok" : "Henüz koleksiyon yok")
                        .foregroundStyle(.secondary)
                        .font(.callout)
                }
                ForEach(visible) { collection in
                    collectionRow(collection)
                }
            }

            Section {
                let visibleHistory = history.filter(historyMatches)
                if visibleHistory.isEmpty {
                    Text(searching ? "Eşleşme yok" : "Henüz istek gönderilmedi")
                        .foregroundStyle(.secondary)
                        .font(.callout)
                }
                ForEach(visibleHistory) { entry in
                    historyRow(entry)
                }
            } header: {
                HStack {
                    Text("Geçmiş")
                    Spacer()
                    if !history.isEmpty {
                        Button {
                            showingClearHistory = true
                        } label: {
                            Text("Temizle")
                        }
                        .buttonStyle(.borderless)
                        .font(.caption)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .confirmationDialog(
            "Tüm geçmiş silinsin mi?",
            isPresented: $showingClearHistory,
            titleVisibility: .visible
        ) {
            Button("Geçmişi Temizle", role: .destructive) {
                store.clearHistory()
            }
            Button("İptal", role: .cancel) {}
        } message: {
            Text("Gönderilmiş tüm istek geçmişi kalıcı olarak silinecek. Kayıtlı koleksiyonlar etkilenmez.")
        }
    }

    // MARK: - Koleksiyon satırı

    private func collectionRow(_ collection: RequestCollection) -> some View {
        DisclosureGroup(isExpanded: collectionExpansion(collection)) {
            let requests = filteredRequests(collection)
            if requests.isEmpty {
                Text("Boş")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            } else {
                let grouped = groupByCategory(requests)
                // Kategorisiz istekler doğrudan.
                ForEach(grouped.uncategorized) { request in
                    requestRow(request)
                }
                // Kategoriler ayrı açılır gruplar halinde.
                ForEach(grouped.categories, id: \.name) { group in
                    DisclosureGroup(isExpanded: categoryExpansion(group.name)) {
                        ForEach(group.requests) { request in
                            requestRow(request)
                        }
                    } label: {
                        Label {
                            Text(group.name)
                        } icon: {
                            Image(systemName: "tag")
                        }
                        .foregroundStyle(.secondary)
                        .font(.caption.weight(.semibold))
                    }
                }
            }
        } label: {
            Label(collection.name ?? "Koleksiyon", systemImage: collection.sourceURL == nil ? "folder" : "folder.badge.gearshape")
                .contextMenu {
                    Button {
                        settingsCollection = collection
                    } label: {
                        Label("Ayarlar…", systemImage: "gearshape")
                    }
                    if collection.sourceURL != nil {
                        Button {
                            Task { await store.refresh(collection) }
                        } label: {
                            Label("Swagger'dan Güncelle", systemImage: "arrow.clockwise")
                        }
                    }
                    Divider()
                    Button("Yeniden Adlandır") {
                        renameText = collection.name ?? ""
                        renamingCollection = collection
                    }
                    Button("Sil", role: .destructive) { store.delete(collection) }
                }
        }
    }

    private func requestRow(_ request: SavedRequest) -> some View {
        Button {
            store.openRequest(request)
        } label: {
            HStack(spacing: 6) {
                MethodBadge(method: HTTPMethod(rawValue: request.method ?? "GET") ?? .get)
                Text(request.name ?? "İstek")
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Sil", role: .destructive) { store.delete(request) }
        }
    }

    private func historyRow(_ entry: HistoryEntry) -> some View {
        Button {
            store.openHistory(entry)
        } label: {
            HStack(spacing: 6) {
                MethodBadge(method: HTTPMethod(rawValue: entry.method ?? "GET") ?? .get)
                Text(entry.urlString ?? "")
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 0)
                Text("\(entry.statusCode)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Sil", role: .destructive) { store.delete(entry) }
        }
    }

    // MARK: - Filtreleme ve gruplama

    private func matches(_ request: SavedRequest) -> Bool {
        guard searching else { return true }
        let q = searchText.lowercased()
        return (request.name ?? "").lowercased().contains(q)
            || (request.urlString ?? "").lowercased().contains(q)
            || (request.method ?? "").lowercased().contains(q)
            || (request.category ?? "").lowercased().contains(q)
    }

    private func filteredRequests(_ collection: RequestCollection) -> [SavedRequest] {
        collection.sortedRequests.filter(matches)
    }

    private func collectionMatches(_ collection: RequestCollection) -> Bool {
        guard searching else { return true }
        if (collection.name ?? "").lowercased().contains(searchText.lowercased()) { return true }
        return !filteredRequests(collection).isEmpty
    }

    private func historyMatches(_ entry: HistoryEntry) -> Bool {
        guard searching else { return true }
        let q = searchText.lowercased()
        return (entry.urlString ?? "").lowercased().contains(q)
            || (entry.method ?? "").lowercased().contains(q)
    }

    private struct CategoryGroup {
        var name: String
        var requests: [SavedRequest]
    }

    private func groupByCategory(_ requests: [SavedRequest]) -> (uncategorized: [SavedRequest], categories: [CategoryGroup]) {
        var uncategorized: [SavedRequest] = []
        var buckets: [String: [SavedRequest]] = [:]
        for request in requests {
            let category = (request.category ?? "").trimmingCharacters(in: .whitespaces)
            if category.isEmpty {
                uncategorized.append(request)
            } else {
                buckets[category, default: []].append(request)
            }
        }
        let categories = buckets.keys.sorted().map { CategoryGroup(name: $0, requests: buckets[$0] ?? []) }
        return (uncategorized, categories)
    }

    // MARK: - Genişleme durumu (arama sırasında zorla açık)

    private func collectionExpansion(_ collection: RequestCollection) -> Binding<Bool> {
        let id = collection.id ?? UUID()
        return Binding(
            get: { searching || expandedCollections.contains(id) },
            set: { isOpen in
                if isOpen { expandedCollections.insert(id) } else { expandedCollections.remove(id) }
            }
        )
    }

    private func categoryExpansion(_ name: String) -> Binding<Bool> {
        Binding(
            get: { searching || expandedCategories.contains(name) },
            set: { isOpen in
                if isOpen { expandedCategories.insert(name) } else { expandedCategories.remove(name) }
            }
        )
    }
}
