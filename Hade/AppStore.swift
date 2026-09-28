//
//  AppStore.swift
//  Hade
//
//  Core Data üzerinde çalışan uygulama durumu ve iş mantığı.
//

import CoreData
import SwiftUI

/// Uygulamanın merkezi durumu: aktif istek taslağı, yanıt ve Core Data işlemleri.
@MainActor
@Observable
final class AppStore {
    @ObservationIgnored let context: NSManagedObjectContext
    @ObservationIgnored private let client = HTTPClient()

    /// Açık istek sekmeleri.
    var tabs: [RequestTab] = []
    /// Aktif sekmenin kimliği.
    var activeTabID: RequestTab.ID?
    /// Bir Swagger/OpenAPI dokümanı içe aktarılıyor mu?
    var isImporting = false
    /// İçe aktarma/kaydetme gibi uygulama düzeyi hata mesajı.
    var importError: String?
    /// Hakkında ekranı gösteriliyor mu?
    var showAbout = false

    /// Çalışma zamanı (script ile atanan) değişkenler — oturum boyunca bellekte tutulur.
    @ObservationIgnored private var sessionVariables: [String: String] = [:]

    init(context: NSManagedObjectContext) {
        self.context = context
        let first = RequestTab()
        tabs = [first]
        activeTabID = first.id
    }

    // MARK: - Aktif sekme ve kolaylık erişimcileri

    /// Şu an aktif olan sekme.
    var activeTab: RequestTab? {
        if let activeTabID, let tab = tabs.first(where: { $0.id == activeTabID }) {
            return tab
        }
        return tabs.first
    }

    /// Editörün bağlandığı geçerli taslak (aktif sekmeye yönlendirir).
    var draft: RequestDraft {
        get { activeTab?.draft ?? RequestDraft() }
        set { activeTab?.draft = newValue }
    }
    var editingRequestID: UUID? {
        get { activeTab?.editingRequestID }
        set { activeTab?.editingRequestID = newValue }
    }
    var response: ResponseResult? {
        get { activeTab?.response }
        set { activeTab?.response = newValue }
    }
    var isSending: Bool {
        get { activeTab?.isSending ?? false }
        set { activeTab?.isSending = newValue }
    }
    var errorMessage: String? {
        get { activeTab?.errorMessage }
        set { activeTab?.errorMessage = newValue }
    }
    var scriptConsole: [String] {
        get { activeTab?.scriptConsole ?? [] }
        set { activeTab?.scriptConsole = newValue }
    }
    var scriptError: String? {
        get { activeTab?.scriptError }
        set { activeTab?.scriptError = newValue }
    }

    // MARK: - Sekme yönetimi

    func newTab() {
        let tab = RequestTab()
        tabs.append(tab)
        activeTabID = tab.id
    }

    func selectTab(_ id: RequestTab.ID) {
        activeTabID = id
    }

    func closeTab(_ id: RequestTab.ID) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        tabs.remove(at: index)
        if tabs.isEmpty {
            let tab = RequestTab()
            tabs = [tab]
            activeTabID = tab.id
        } else if activeTabID == id {
            activeTabID = tabs[min(index, tabs.count - 1)].id
        }
    }

    /// Kayıtlı bir isteği yeni bir sekmede açar (zaten açıksa o sekmeyi öne getirir).
    func openRequest(_ saved: SavedRequest) {
        if let existing = tabs.first(where: { $0.editingRequestID == saved.id }) {
            activeTabID = existing.id
            return
        }
        let tab = RequestTab(draft: makeDraft(from: saved), editingRequestID: saved.id)
        tabs.append(tab)
        activeTabID = tab.id
    }

    /// Geçmişteki bir isteği yeni bir sekmede açar.
    func openHistory(_ entry: HistoryEntry) {
        guard let json = entry.snapshotJSON,
              let data = json.data(using: .utf8),
              let restored = try? JSONDecoder().decode(RequestDraft.self, from: data) else {
            return
        }
        let tab = RequestTab(draft: restored)
        tabs.append(tab)
        activeTabID = tab.id
    }

    // MARK: - İstek gönderme

    func send() async {
        guard let tab = activeTab else { return }
        await send(tab)
    }

    /// Belirli bir sekmenin isteğini gönderir.
    func send(_ tab: RequestTab) async {
        tab.errorMessage = nil
        tab.scriptConsole = []
        tab.scriptError = nil
        tab.isSending = true
        defer { tab.isSending = false }

        let resolver = activeResolver(for: tab.draft)
        var outgoing = tab.draft
        applyCollectionAuthorization(to: &outgoing)
        do {
            let result = try await client.send(outgoing, resolver: resolver)
            tab.response = result
            recordHistory(for: tab.draft, result: result, resolver: resolver)
            runScript(for: tab, response: result)
        } catch is CancellationError {
            // Kullanıcı iptal etti — sessizce geç.
        } catch {
            tab.errorMessage = error.localizedDescription
        }
    }

    /// İsteğin ait olduğu koleksiyonda `authorization` tipli, dolu bir değişken varsa,
    /// bunu Authorization header'ı olarak uygular. Boş bir Authorization header'ı varsa
    /// (ör. içe aktarımdan gelen) onu doldurur; yoksa yeni header ekler. Kullanıcının
    /// elle girdiği (dolu) bir Authorization header'ına dokunmaz.
    private func applyCollectionAuthorization(to draft: inout RequestDraft) {
        guard let value = collectionAuthorizationValue(for: draft) else { return }

        func isAuthKey(_ item: KeyValue) -> Bool {
            item.key.trimmingCharacters(in: .whitespaces).lowercased() == "authorization"
        }

        // Kullanıcı dolu bir Authorization header'ı girmişse ona dokunma.
        let hasExplicit = draft.headers.contains {
            $0.enabled && isAuthKey($0) && !$0.value.trimmingCharacters(in: .whitespaces).isEmpty
        }
        guard !hasExplicit else { return }

        if let index = draft.headers.firstIndex(where: isAuthKey) {
            draft.headers[index].value = value
            draft.headers[index].enabled = true
        } else {
            draft.headers.append(KeyValue(key: "Authorization", value: value, enabled: true))
        }
    }

    /// Koleksiyonun `authorization` tipli, etkin ve dolu değişkeninin değeri.
    private func collectionAuthorizationValue(for draft: RequestDraft) -> String? {
        guard let id = draft.collectionID, let collection = collection(with: id) else { return nil }
        let vars = Self.decodeKeyValues(collection.variablesJSON)
        return vars.first(where: {
            $0.type == .authorization && $0.enabled && !$0.value.trimmingCharacters(in: .whitespaces).isEmpty
        })?.value
    }

    /// Sekmedeki istekte bir post-response script varsa çalıştırır ve değişkenleri uygular.
    private func runScript(for tab: RequestTab, response result: ResponseResult) {
        let script = tab.draft.scriptText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !script.isEmpty else { return }

        let scriptResult = ScriptRunner.run(script: tab.draft.scriptText, response: result)
        tab.scriptConsole = scriptResult.logs
        tab.scriptError = scriptResult.error
        guard !scriptResult.variables.isEmpty else { return }
        applyScriptVariables(scriptResult.variables, draft: tab.draft)
    }

    /// Script ile atanan değişkenleri oturuma ve (varsa) koleksiyona yazar.
    private func applyScriptVariables(_ variables: [String: String], draft: RequestDraft) {
        for (key, value) in variables {
            sessionVariables[key] = value
        }
        guard let id = draft.collectionID, let collection = collection(with: id) else { return }
        var items = Self.decodeKeyValues(collection.variablesJSON)
        for (key, value) in variables {
            if let index = items.firstIndex(where: { $0.key == key }) {
                items[index].value = value
                items[index].enabled = true
            } else {
                items.append(KeyValue(key: key, value: value, enabled: true))
            }
        }
        collection.variablesJSON = Self.encodeKeyValues(items)
        persist()
    }

    // MARK: - Ortam değişkenleri

    /// Koleksiyon + aktif ortam + çalışma zamanı değişkenlerini birleştirip çözümleyici üretir.
    /// Öncelik (düşükten yükseğe): koleksiyon < ortam < çalışma zamanı (script).
    func activeResolver(for draft: RequestDraft) -> VariableResolver {
        var dict: [String: String] = [:]

        // 1. Koleksiyon değişkenleri
        if let id = draft.collectionID, let collection = collection(with: id) {
            merge(Self.decodeKeyValues(collection.variablesJSON), into: &dict)
        }
        // 2. Aktif ortam değişkenleri (koleksiyonu geçersiz kılar)
        if let env = activeEnvironment() {
            merge(Self.decodeKeyValues(env.variablesJSON), into: &dict)
        }
        // 3. Çalışma zamanı değişkenleri (en yüksek öncelik)
        for (key, value) in sessionVariables {
            dict[key] = value
        }

        return VariableResolver(variables: dict)
    }

    private func merge(_ items: [KeyValue], into dict: inout [String: String]) {
        for item in items where item.enabled && !item.key.isEmpty {
            dict[item.key] = item.value
        }
    }

    private func activeEnvironment() -> AppEnvironment? {
        let request = AppEnvironment.fetchRequest()
        request.predicate = NSPredicate(format: "isActive == YES")
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }

    private func collection(with id: UUID) -> RequestCollection? {
        let request = RequestCollection.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }

    /// Koleksiyon değişkenlerini günceller.
    func setVariables(_ items: [KeyValue], for collection: RequestCollection) {
        collection.variablesJSON = Self.encodeKeyValues(items)
        persist()
    }

    /// Koleksiyonun güncellenebilir kaynak URL'sini ayarlar.
    func setSourceURL(_ url: String?, for collection: RequestCollection) {
        let trimmed = url?.trimmingCharacters(in: .whitespacesAndNewlines)
        collection.sourceURL = (trimmed?.isEmpty ?? true) ? nil : trimmed
        persist()
    }

    // MARK: - Taslak <-> Core Data dönüşümü

    /// Kayıtlı bir isteği bir `RequestDraft`'a dönüştürür.
    private func makeDraft(from saved: SavedRequest) -> RequestDraft {
        RequestDraft(
            id: saved.id ?? UUID(),
            name: saved.name ?? "İstek",
            method: HTTPMethod(rawValue: saved.method ?? "GET") ?? .get,
            urlString: saved.urlString ?? "",
            queryItems: Self.decodeKeyValues(saved.queryJSON),
            headers: Self.decodeKeyValues(saved.headersJSON),
            bodyKind: BodyKind(rawValue: saved.bodyType ?? "none") ?? .none,
            bodyText: saved.bodyText ?? "",
            formFields: Self.decodeKeyValues(saved.formJSON),
            scriptText: saved.scriptText ?? "",
            collectionID: saved.collection?.id,
            category: saved.category ?? "",
            requiresAuth: saved.requiresAuth
        )
    }

    // MARK: - Kaydetme / güncelleme

    /// Geçerli taslağı yeni bir kayıtlı istek olarak koleksiyona ekler.
    func saveDraft(to collection: RequestCollection) {
        let saved = SavedRequest(context: context)
        saved.id = draft.id
        saved.createdAt = Date()
        apply(draft, to: saved)
        saved.collection = collection
        saved.sortIndex = Int64((collection.requests?.count ?? 1) - 1)
        draft.collectionID = collection.id
        editingRequestID = saved.id
        persist()
    }

    /// Düzenlenen kayıtlı isteği günceller. Yeni ise `false` döner.
    @discardableResult
    func updateEditingRequest() -> Bool {
        guard let id = editingRequestID,
              let saved = savedRequest(with: id) else {
            return false
        }
        apply(draft, to: saved)
        persist()
        return true
    }

    /// Verilen taslak değerlerini Core Data nesnesine uygular.
    private func apply(_ draft: RequestDraft, to saved: SavedRequest) {
        saved.name = draft.name
        saved.method = draft.method.rawValue
        saved.urlString = draft.urlString
        saved.queryJSON = Self.encodeKeyValues(draft.queryItems)
        saved.headersJSON = Self.encodeKeyValues(draft.headers)
        saved.bodyType = draft.bodyKind.rawValue
        saved.bodyText = draft.bodyText
        saved.formJSON = Self.encodeKeyValues(draft.formFields)
        saved.scriptText = draft.scriptText
        saved.category = draft.category
        saved.requiresAuth = draft.requiresAuth
        saved.updatedAt = Date()
    }

    // MARK: - Koleksiyon işlemleri

    @discardableResult
    func addCollection(name: String) -> RequestCollection {
        let collection = RequestCollection(context: context)
        collection.id = UUID()
        collection.name = name.isEmpty ? "Yeni Koleksiyon" : name
        collection.createdAt = Date()
        collection.sortIndex = Int64(collectionCount())
        persist()
        return collection
    }

    func rename(_ collection: RequestCollection, to name: String) {
        collection.name = name
        persist()
    }

    func delete(_ collection: RequestCollection) {
        context.delete(collection)
        persist()
    }

    func delete(_ request: SavedRequest) {
        // Bu isteği düzenleyen sekmeleri "kaydedilmemiş" duruma al.
        for tab in tabs where tab.editingRequestID == request.id {
            tab.editingRequestID = nil
        }
        context.delete(request)
        persist()
    }

    // MARK: - Swagger / OpenAPI içe aktarma

    /// Bir URL'den doküman indirip yeni koleksiyon oluşturur.
    func importCollection(fromURLString urlString: String) async {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), url.scheme != nil else {
            importError = "Geçersiz URL: \(trimmed)"
            return
        }
        importError = nil
        isImporting = true
        defer { isImporting = false }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            try importCollection(from: data, sourceURL: trimmed)
        } catch let error as OpenAPIImportError {
            importError = error.errorDescription
        } catch {
            importError = "İçe aktarılamadı: \(error.localizedDescription)"
        }
    }

    /// Ham doküman verisinden yeni koleksiyon oluşturur.
    @discardableResult
    func importCollection(from data: Data, sourceURL: String?) throws -> RequestCollection {
        let imported = try OpenAPIImporter.parse(data: data, sourceURL: sourceURL)
        let collection = RequestCollection(context: context)
        collection.id = UUID()
        collection.name = imported.name
        collection.createdAt = Date()
        collection.sortIndex = Int64(collectionCount())
        collection.sourceURL = sourceURL
        var vars: [KeyValue] = []
        if !imported.baseURL.isEmpty {
            vars.append(KeyValue(key: "baseUrl", value: imported.baseURL, enabled: true))
        }
        // Auth gerektiren uç varsa, doldurulmak üzere bir Authorization değişkeni ekle.
        if imported.requiresAuthAnywhere {
            vars.append(KeyValue(key: "authorization", value: "", enabled: true, type: .authorization))
        }
        if !vars.isEmpty {
            collection.variablesJSON = Self.encodeKeyValues(vars)
        }
        populate(collection, with: imported)
        persist()
        return collection
    }

    /// Koleksiyonu kayıtlı kaynağından yeniden indirip günceller.
    func refresh(_ collection: RequestCollection) async {
        guard let source = collection.sourceURL, let url = URL(string: source) else {
            importError = "Bu koleksiyonun güncellenebilir bir kaynağı yok."
            return
        }
        importError = nil
        isImporting = true
        defer { isImporting = false }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let imported = try OpenAPIImporter.parse(data: data, sourceURL: source)
            // Mevcut istekleri değiştir.
            let deletedIDs = Set(collection.sortedRequests.compactMap { $0.id })
            for tab in tabs where tab.editingRequestID.map(deletedIDs.contains) ?? false {
                tab.editingRequestID = nil
            }
            for request in collection.sortedRequests {
                context.delete(request)
            }
            collection.name = imported.name
            // baseUrl değişkenini güncelle, diğer (ör. script ile atanmış) değişkenleri koru.
            if !imported.baseURL.isEmpty {
                var items = Self.decodeKeyValues(collection.variablesJSON)
                if let index = items.firstIndex(where: { $0.key == "baseUrl" }) {
                    items[index].value = imported.baseURL
                } else {
                    items.append(KeyValue(key: "baseUrl", value: imported.baseURL, enabled: true))
                }
                collection.variablesJSON = Self.encodeKeyValues(items)
            }
            populate(collection, with: imported)
            persist()
        } catch let error as OpenAPIImportError {
            importError = error.errorDescription
        } catch {
            importError = "Güncellenemedi: \(error.localizedDescription)"
        }
    }

    /// İçe aktarılan istekleri koleksiyona ekler.
    private func populate(_ collection: RequestCollection, with imported: ImportedCollection) {
        for (index, draft) in imported.requests.enumerated() {
            let saved = SavedRequest(context: context)
            saved.id = draft.id
            saved.createdAt = Date()
            apply(draft, to: saved)
            saved.collection = collection
            saved.sortIndex = Int64(index)
        }
    }

    // MARK: - Ortam işlemleri

    @discardableResult
    func addEnvironment(name: String) -> AppEnvironment {
        let env = AppEnvironment(context: context)
        env.id = UUID()
        env.name = name.isEmpty ? "Yeni Ortam" : name
        env.createdAt = Date()
        env.isActive = !hasAnyEnvironment()
        env.variablesJSON = "[]"
        persist()
        return env
    }

    /// Tüm ortamları pasifleştirir (değişken yok).
    func deactivateAllEnvironments() {
        let request = AppEnvironment.fetchRequest()
        if let all = try? context.fetch(request) {
            for item in all { item.isActive = false }
        }
        persist()
    }

    /// Tek bir ortamı aktif yapar, diğerlerini pasifleştirir.
    func activate(_ env: AppEnvironment) {
        let request = AppEnvironment.fetchRequest()
        if let all = try? context.fetch(request) {
            for item in all {
                item.isActive = (item.objectID == env.objectID)
            }
        }
        persist()
    }

    func setVariables(_ items: [KeyValue], for env: AppEnvironment) {
        env.variablesJSON = Self.encodeKeyValues(items)
        persist()
    }

    func rename(_ env: AppEnvironment, to name: String) {
        env.name = name
        persist()
    }

    func delete(_ env: AppEnvironment) {
        context.delete(env)
        persist()
    }

    // MARK: - Geçmiş

    private func recordHistory(for draft: RequestDraft, result: ResponseResult, resolver: VariableResolver) {
        let entry = HistoryEntry(context: context)
        entry.id = UUID()
        entry.method = draft.method.rawValue
        entry.urlString = resolver.resolve(draft.urlString)
        entry.statusCode = Int64(result.statusCode)
        entry.durationMs = result.durationMs
        entry.responseSize = Int64(result.byteCount)
        entry.timestamp = Date()
        if let data = try? JSONEncoder().encode(draft) {
            entry.snapshotJSON = String(data: data, encoding: .utf8)
        }
        persist()
    }

    func clearHistory() {
        let request: NSFetchRequest<NSFetchRequestResult> = HistoryEntry.fetchRequest()
        let delete = NSBatchDeleteRequest(fetchRequest: request)
        _ = try? context.execute(delete)
        // Batch silme bağlamı otomatik güncellemez; nesneleri yenile.
        context.refreshAllObjects()
    }

    func delete(_ entry: HistoryEntry) {
        context.delete(entry)
        persist()
    }

    // MARK: - Yardımcılar

    private func savedRequest(with id: UUID) -> SavedRequest? {
        let request = SavedRequest.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }

    private func collectionCount() -> Int {
        (try? context.count(for: RequestCollection.fetchRequest())) ?? 0
    }

    private func hasAnyEnvironment() -> Bool {
        ((try? context.count(for: AppEnvironment.fetchRequest())) ?? 0) > 0
    }

    private func persist() {
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            importError = "Kaydedilemedi: \(error.localizedDescription)"
        }
    }

    // MARK: - JSON kodlama

    static func encodeKeyValues(_ items: [KeyValue]) -> String {
        guard let data = try? JSONEncoder().encode(items),
              let string = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return string
    }

    static func decodeKeyValues(_ json: String?) -> [KeyValue] {
        guard let json, let data = json.data(using: .utf8),
              let items = try? JSONDecoder().decode([KeyValue].self, from: data) else {
            return []
        }
        return items
    }
}
