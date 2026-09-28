//
//  HTTPModels.swift
//  Hade
//
//  API benzeri istek/yanıt için çekirdek veri tipleri.
//

import Foundation

/// Desteklenen HTTP metotları.
enum HTTPMethod: String, CaseIterable, Codable, Identifiable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
    case head = "HEAD"
    case options = "OPTIONS"

    var id: String { rawValue }

    /// Metoda özel renk ipucu (arayüzde etiket rengi için).
    var tintName: String {
        switch self {
        case .get: return "green"
        case .post: return "orange"
        case .put: return "blue"
        case .patch: return "purple"
        case .delete: return "red"
        case .head, .options: return "gray"
        }
    }

    /// Bu metot gövde (body) taşıyabilir mi?
    var allowsBody: Bool {
        switch self {
        case .get, .head: return false
        default: return true
        }
    }
}

/// İstek gövdesinin türü.
enum BodyKind: String, CaseIterable, Codable, Identifiable {
    case none
    case json
    case text
    case form

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: return "Yok"
        case .json: return "JSON"
        case .text: return "Düz Metin"
        case .form: return "Form (x-www-form-urlencoded)"
        }
    }
}

/// Değişken/parametre tipi.
enum KeyValueType: String, Codable, CaseIterable, Identifiable {
    case text
    case secret
    case authorization

    var id: String { rawValue }

    var label: String {
        switch self {
        case .text: return "Metin"
        case .secret: return "Gizli"
        case .authorization: return "Authorization"
        }
    }
}

/// Header, query parametresi ve form alanları için ortak anahtar/değer satırı.
struct KeyValue: Codable, Identifiable, Hashable {
    var id: UUID
    var key: String
    var value: String
    var enabled: Bool
    /// Değişken tipi (yalnızca koleksiyon değişkenlerinde anlamlı).
    var type: KeyValueType

    init(id: UUID = UUID(), key: String = "", value: String = "", enabled: Bool = true, type: KeyValueType = .text) {
        self.id = id
        self.key = key
        self.value = value
        self.enabled = enabled
        self.type = type
    }

    // Eski kayıtlarda `type` bulunmayabilir; eksikse metin kabul et.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        key = try c.decode(String.self, forKey: .key)
        value = try c.decode(String.self, forKey: .value)
        enabled = try c.decode(Bool.self, forKey: .enabled)
        type = try c.decodeIfPresent(KeyValueType.self, forKey: .type) ?? .text
    }

    var isBlank: Bool {
        key.trimmingCharacters(in: .whitespaces).isEmpty &&
        value.trimmingCharacters(in: .whitespaces).isEmpty
    }
}

/// Düzenlenebilir istek taslağı — editörün üzerinde çalıştığı bellek içi model.
struct RequestDraft: Codable, Equatable, Identifiable {
    var id: UUID
    var name: String
    var method: HTTPMethod
    var urlString: String
    var queryItems: [KeyValue]
    var headers: [KeyValue]
    var bodyKind: BodyKind
    var bodyText: String
    /// x-www-form-urlencoded gövdesi için alanlar.
    var formFields: [KeyValue]
    /// Yanıt döndükten sonra çalışan JavaScript (post-response script).
    var scriptText: String
    /// İsteğin ait olduğu koleksiyonun kimliği (değişken çözümleme/script yazımı için).
    var collectionID: UUID?
    /// İsteğin kategorisi (ör. OpenAPI tag'i) — koleksiyon içinde gruplama için.
    var category: String
    /// İstek kimlik doğrulama (Authorization) gerektiriyor mu? (OpenAPI security)
    var requiresAuth: Bool

    init(
        id: UUID = UUID(),
        name: String = "Yeni İstek",
        method: HTTPMethod = .get,
        urlString: String = "",
        queryItems: [KeyValue] = [],
        headers: [KeyValue] = [],
        bodyKind: BodyKind = .none,
        bodyText: String = "",
        formFields: [KeyValue] = [],
        scriptText: String = "",
        collectionID: UUID? = nil,
        category: String = "",
        requiresAuth: Bool = false
    ) {
        self.id = id
        self.name = name
        self.method = method
        self.urlString = urlString
        self.queryItems = queryItems
        self.headers = headers
        self.bodyKind = bodyKind
        self.bodyText = bodyText
        self.formFields = formFields
        self.scriptText = scriptText
        self.collectionID = collectionID
        self.category = category
        self.requiresAuth = requiresAuth
    }

    // Geçmişteki eski kayıtlarda yeni alanlar bulunmayabilir; eksikse varsayılan kullan.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        method = try c.decode(HTTPMethod.self, forKey: .method)
        urlString = try c.decode(String.self, forKey: .urlString)
        queryItems = try c.decode([KeyValue].self, forKey: .queryItems)
        headers = try c.decode([KeyValue].self, forKey: .headers)
        bodyKind = try c.decode(BodyKind.self, forKey: .bodyKind)
        bodyText = try c.decode(String.self, forKey: .bodyText)
        formFields = try c.decodeIfPresent([KeyValue].self, forKey: .formFields) ?? []
        scriptText = try c.decodeIfPresent(String.self, forKey: .scriptText) ?? ""
        collectionID = try c.decodeIfPresent(UUID.self, forKey: .collectionID)
        category = try c.decodeIfPresent(String.self, forKey: .category) ?? ""
        requiresAuth = try c.decodeIfPresent(Bool.self, forKey: .requiresAuth) ?? false
    }
}

/// Bir isteğin sonucunda dönen yanıt.
struct ResponseResult: Identifiable {
    let id = UUID()
    var statusCode: Int
    var statusText: String
    var headers: [(String, String)]
    var body: Data
    var durationMs: Double
    var finalURL: String

    var byteCount: Int { body.count }

    /// Yanıt gövdesini metin olarak döndürür.
    var bodyString: String {
        String(data: body, encoding: .utf8) ?? "<ikili veri, \(byteCount) bayt>"
    }

    /// İçerik JSON ise güzel biçimlendirilmiş halini döndürür, değilse ham metni.
    var prettyBody: String {
        guard
            let object = try? JSONSerialization.jsonObject(with: body),
            let pretty = try? JSONSerialization.data(
                withJSONObject: object,
                options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            ),
            let text = String(data: pretty, encoding: .utf8)
        else {
            return bodyString
        }
        return text
    }

    var isJSON: Bool {
        (try? JSONSerialization.jsonObject(with: body)) != nil
    }

    /// Durum koduna göre renk ipucu.
    var statusTintName: String {
        switch statusCode {
        case 200..<300: return "green"
        case 300..<400: return "blue"
        case 400..<500: return "orange"
        case 500...: return "red"
        default: return "gray"
        }
    }
}

/// İnsan tarafından okunabilir boyut biçimlendirme yardımcıları.
enum Format {
    static func size(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: Int64(bytes))
    }

    static func duration(_ ms: Double) -> String {
        if ms < 1000 {
            return String(format: "%.0f ms", ms)
        }
        return String(format: "%.2f s", ms / 1000)
    }
}
