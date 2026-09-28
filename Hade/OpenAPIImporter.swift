//
//  OpenAPIImporter.swift
//  Hade
//
//  OpenAPI 3 ve Swagger 2 JSON dokümanlarını koleksiyon + istek taslaklarına çevirir.
//

import Foundation

/// İçe aktarma sonucunda oluşan koleksiyon.
struct ImportedCollection {
    var name: String
    var baseURL: String
    var requests: [RequestDraft]
    /// İçinde en az bir kimlik doğrulama gerektiren uç var mı?
    var requiresAuthAnywhere: Bool
}

enum OpenAPIImportError: LocalizedError {
    case invalidJSON
    case unsupportedFormat
    case noOperations

    var errorDescription: String? {
        switch self {
        case .invalidJSON:
            return "Doküman geçerli bir JSON değil. (YAML dosyaları henüz desteklenmiyor — JSON çıktısını kullanın.)"
        case .unsupportedFormat:
            return "Desteklenmeyen biçim. 'openapi' (3.x) veya 'swagger' (2.0) alanı bulunamadı."
        case .noOperations:
            return "Dokümanda hiçbir işlem (path/operation) bulunamadı."
        }
    }
}

/// OpenAPI/Swagger JSON'ı ayrıştıran yardımcı.
struct OpenAPIImporter {
    /// Bilinen HTTP metotları (path item içindeki anahtarlar).
    private static let methodKeys = ["get", "post", "put", "patch", "delete", "head", "options"]

    static func parse(data: Data, sourceURL: String?) throws -> ImportedCollection {
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            throw OpenAPIImportError.invalidJSON
        }

        let isV3 = (root["openapi"] as? String)?.hasPrefix("3") ?? false
        let isV2 = (root["swagger"] as? String)?.hasPrefix("2") ?? false
        guard isV3 || isV2 else { throw OpenAPIImportError.unsupportedFormat }

        let info = root["info"] as? [String: Any]
        let title = (info?["title"] as? String) ?? "İçe Aktarılan API"

        let base = isV3
            ? baseURLForV3(root: root, sourceURL: sourceURL)
            : baseURLForV2(root: root, sourceURL: sourceURL)

        guard let paths = root["paths"] as? [String: Any] else {
            throw OpenAPIImportError.noOperations
        }

        var requests: [RequestDraft] = []
        var requiresAuthAnywhere = false
        // Base URL boş değilse istekleri {{baseUrl}} değişkeniyle kur.
        let usePlaceholder = !base.isEmpty
        // Global güvenlik gereksinimi (operation kendi security'siyle geçersiz kılabilir).
        let globalSecurity = root["security"] as? [[String: Any]]

        for path in paths.keys.sorted() {
            guard let pathItem = paths[path] as? [String: Any] else { continue }

            // Path seviyesindeki ortak parametreler.
            let sharedParams = pathItem["parameters"] as? [[String: Any]] ?? []

            for method in Self.methodKeys {
                guard let operation = pathItem[method] as? [String: Any] else { continue }

                let httpMethod = HTTPMethod(rawValue: method.uppercased()) ?? .get
                let name = operationName(operation, method: httpMethod, path: path)
                // İlk tag'i kategori olarak kullan (koleksiyon içinde gruplama için).
                let category = (operation["tags"] as? [String])?.first ?? ""
                // Kimlik doğrulama gerekli mi?
                let requiresAuth: Bool
                if let opSecurity = operation["security"] as? [[String: Any]] {
                    requiresAuth = !opSecurity.isEmpty
                } else {
                    requiresAuth = !(globalSecurity?.isEmpty ?? true)
                }
                if requiresAuth { requiresAuthAnywhere = true }

                var params = sharedParams
                params.append(contentsOf: operation["parameters"] as? [[String: Any]] ?? [])

                var query: [KeyValue] = []
                var headers: [KeyValue] = []
                for param in params {
                    guard let inValue = param["in"] as? String,
                          let key = param["name"] as? String else { continue }
                    let required = (param["required"] as? Bool) ?? false
                    let value = scalarExample(from: param)
                    let item = KeyValue(key: key, value: value, enabled: required)
                    switch inValue {
                    case "query": query.append(item)
                    case "header": headers.append(item)
                    default: break
                    }
                }

                var bodyKind: BodyKind = .none
                var bodyText = ""
                if let body = requestBodyJSON(operation: operation, params: params, isV3: isV3, root: root) {
                    bodyKind = .json
                    bodyText = body
                }

                requests.append(RequestDraft(
                    name: name,
                    method: httpMethod,
                    urlString: usePlaceholder ? join(base: "{{baseUrl}}", path: path) : path,
                    queryItems: query,
                    headers: headers,
                    bodyKind: bodyKind,
                    bodyText: bodyText,
                    category: category,
                    requiresAuth: requiresAuth,
                    docs: buildDocs(operation: operation, params: params, method: httpMethod, path: path)
                ))
            }
        }

        guard !requests.isEmpty else { throw OpenAPIImportError.noOperations }

        return ImportedCollection(name: title, baseURL: base, requests: requests, requiresAuthAnywhere: requiresAuthAnywhere)
    }

    // MARK: - Base URL

    private static func baseURLForV3(root: [String: Any], sourceURL: String?) -> String {
        if let servers = root["servers"] as? [[String: Any]],
           let first = servers.first,
           let url = first["url"] as? String,
           !url.isEmpty {
            if url.contains("://") {
                return trimSlash(url)
            }
            // Göreli sunucu yolu — kaynak kökeniyle birleştir.
            return trimSlash(origin(of: sourceURL) + (url.hasPrefix("/") ? url : "/" + url))
        }
        return trimSlash(origin(of: sourceURL))
    }

    private static func baseURLForV2(root: [String: Any], sourceURL: String?) -> String {
        let schemes = root["schemes"] as? [String]
        let scheme = schemes?.first ?? URL(string: sourceURL ?? "")?.scheme ?? "https"
        let host = (root["host"] as? String) ?? URL(string: sourceURL ?? "")?.host ?? ""
        let basePath = (root["basePath"] as? String) ?? ""
        if host.isEmpty {
            return trimSlash(origin(of: sourceURL) + basePath)
        }
        return trimSlash("\(scheme)://\(host)\(basePath)")
    }

    /// Kaynak URL'den şema://host[:port] köğü üretir.
    private static func origin(of sourceURL: String?) -> String {
        guard let sourceURL, let components = URLComponents(string: sourceURL),
              let scheme = components.scheme, let host = components.host else {
            return ""
        }
        if let port = components.port {
            return "\(scheme)://\(host):\(port)"
        }
        return "\(scheme)://\(host)"
    }

    // MARK: - Yardımcılar

    private static func operationName(_ operation: [String: Any], method: HTTPMethod, path: String) -> String {
        if let summary = operation["summary"] as? String, !summary.isEmpty { return summary }
        if let id = operation["operationId"] as? String, !id.isEmpty { return id }
        return "\(method.rawValue) \(path)"
    }

    /// Query/header parametresi için kısa örnek değer.
    private static func scalarExample(from param: [String: Any]) -> String {
        if let example = param["example"] { return string(from: example) }
        if let def = param["default"] { return string(from: def) }
        if let schema = param["schema"] as? [String: Any] {
            if let example = schema["example"] { return string(from: example) }
            if let def = schema["default"] { return string(from: def) }
        }
        return ""
    }

    /// İstek gövdesi için JSON örneği (v3 requestBody veya v2 body parametresi).
    /// Açık `example` yoksa şemadan (referanslar çözülerek) örnek bir gövde üretir.
    private static func requestBodyJSON(operation: [String: Any], params: [[String: Any]], isV3: Bool, root: [String: Any]) -> String? {
        let schema: [String: Any]?
        let explicitExample: Any?

        if isV3 {
            guard let requestBody = operation["requestBody"] as? [String: Any],
                  let content = requestBody["content"] as? [String: Any],
                  let json = content["application/json"] as? [String: Any] else {
                return nil
            }
            explicitExample = json["example"]
            schema = json["schema"] as? [String: Any]
        } else {
            guard let bodyParam = params.first(where: { ($0["in"] as? String) == "body" }) else {
                return nil
            }
            explicitExample = bodyParam["example"]
            schema = bodyParam["schema"] as? [String: Any]
        }

        if let explicitExample { return prettyJSON(from: explicitExample) }
        if let schema, let sample = sampleValue(for: schema, root: root, visited: []) {
            return prettyJSON(from: sample)
        }
        return "{\n\n}"
    }

    /// Operasyondan Bilgi sekmesi için markdown doküman üretir.
    private static func buildDocs(operation: [String: Any], params: [[String: Any]], method: HTTPMethod, path: String) -> String {
        var lines: [String] = []
        lines.append("**\(method.rawValue) \(path)**")

        if let summary = operation["summary"] as? String,
           !summary.trimmingCharacters(in: .whitespaces).isEmpty {
            lines.append("")
            lines.append(summary)
        }
        if let description = operation["description"] as? String,
           !description.trimmingCharacters(in: .whitespaces).isEmpty {
            lines.append("")
            lines.append(description)
        }

        // Parametreler
        let docParams = params.filter { p in
            let inValue = p["in"] as? String
            return inValue == "query" || inValue == "header" || inValue == "path"
        }
        if !docParams.isEmpty {
            lines.append("")
            lines.append("**Parametreler**")
            for p in docParams {
                let name = (p["name"] as? String) ?? "?"
                let inValue = (p["in"] as? String) ?? ""
                let required = (p["required"] as? Bool) ?? false
                let desc = (p["description"] as? String) ?? ""
                var line = "- `\(name)` (\(inValue)\(required ? ", zorunlu" : ""))"
                if !desc.trimmingCharacters(in: .whitespaces).isEmpty { line += " — \(desc)" }
                lines.append(line)
            }
        }

        // İstek gövdesi açıklaması
        if let requestBody = operation["requestBody"] as? [String: Any],
           let desc = requestBody["description"] as? String,
           !desc.trimmingCharacters(in: .whitespaces).isEmpty {
            lines.append("")
            lines.append("**Gövde**")
            lines.append(desc)
        }

        // Yanıtlar
        if let responses = operation["responses"] as? [String: Any], !responses.isEmpty {
            lines.append("")
            lines.append("**Yanıtlar**")
            for code in responses.keys.sorted() {
                let info = responses[code] as? [String: Any]
                let desc = (info?["description"] as? String) ?? ""
                lines.append("- `\(code)`\(desc.isEmpty ? "" : " — \(desc)")")
            }
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Şemadan örnek üretimi

    /// Bir JSON şemasından örnek bir değer üretir ($ref'leri çözerek, döngüye karşı korumalı).
    private static func sampleValue(for schema: [String: Any], root: [String: Any], visited: Set<String>) -> Any? {
        var schema = schema
        var visited = visited

        // $ref çözümü (döngü koruması).
        if let ref = schema["$ref"] as? String {
            guard !visited.contains(ref), let resolved = resolveRef(ref, root: root) else {
                return [:] as [String: Any]
            }
            visited.insert(ref)
            schema = resolved
        }

        // Açık örnek/varsayılan/enum önceliklidir.
        if let example = schema["example"] { return example }
        if let def = schema["default"] { return def }
        if let enumValues = schema["enum"] as? [Any], let first = enumValues.first { return first }

        // Kompozisyon: allOf birleştir, oneOf/anyOf ilkini kullan.
        if let allOf = schema["allOf"] as? [[String: Any]] {
            var merged: [String: Any] = [:]
            for sub in allOf {
                if let value = sampleValue(for: sub, root: root, visited: visited) as? [String: Any] {
                    merged.merge(value) { _, new in new }
                }
            }
            if !merged.isEmpty { return merged }
        }
        if let composed = (schema["oneOf"] as? [[String: Any]] ?? schema["anyOf"] as? [[String: Any]])?.first {
            return sampleValue(for: composed, root: root, visited: visited)
        }

        let type = schema["type"] as? String

        if type == "object" || schema["properties"] != nil {
            var object: [String: Any] = [:]
            if let properties = schema["properties"] as? [String: Any] {
                for (key, value) in properties {
                    if let propSchema = value as? [String: Any] {
                        object[key] = sampleValue(for: propSchema, root: root, visited: visited) ?? NSNull()
                    }
                }
            }
            return object
        }

        if type == "array" {
            if let items = schema["items"] as? [String: Any],
               let element = sampleValue(for: items, root: root, visited: visited) {
                return [element]
            }
            return [Any]()
        }

        switch type {
        case "integer": return 0
        case "number": return 0
        case "boolean": return false
        case "string": return sampleString(for: schema["format"] as? String)
        default: return NSNull()
        }
    }

    /// String formatına göre makul bir örnek değer.
    private static func sampleString(for format: String?) -> String {
        switch format {
        case "date-time": return "2020-01-01T00:00:00Z"
        case "date": return "2020-01-01"
        case "uuid": return "00000000-0000-0000-0000-000000000000"
        case "email": return "user@example.com"
        case "uri", "url": return "https://example.com"
        case "byte": return "ZXhhbXBsZQ=="
        case "password": return "••••••••"
        default: return "string"
        }
    }

    /// JSON Pointer ($ref) referansını kök dokümanda çözer.
    private static func resolveRef(_ ref: String, root: [String: Any]) -> [String: Any]? {
        guard ref.hasPrefix("#/") else { return nil }
        var node: Any = root
        for rawPart in ref.dropFirst(2).split(separator: "/") {
            let key = rawPart
                .replacingOccurrences(of: "~1", with: "/")
                .replacingOccurrences(of: "~0", with: "~")
            guard let dict = node as? [String: Any], let next = dict[key] else { return nil }
            node = next
        }
        return node as? [String: Any]
    }

    /// Herhangi bir JSON değerini kısa metne çevirir (skaler için).
    private static func string(from value: Any) -> String {
        switch value {
        case let s as String: return s
        case let b as Bool: return b ? "true" : "false"
        case let n as NSNumber: return n.stringValue
        default: return prettyJSON(from: value)
        }
    }

    /// Bir JSON değerini güzel biçimlendirilmiş metne çevirir.
    private static func prettyJSON(from value: Any) -> String {
        guard JSONSerialization.isValidJSONObject(value),
              let data = try? JSONSerialization.data(
                withJSONObject: value,
                options: [.prettyPrinted, .withoutEscapingSlashes]
              ),
              let text = String(data: data, encoding: .utf8) else {
            return "\(value)"
        }
        return text
    }

    private static func trimSlash(_ s: String) -> String {
        s.hasSuffix("/") ? String(s.dropLast()) : s
    }

    private static func join(base: String, path: String) -> String {
        if base.isEmpty { return path }
        let p = path.hasPrefix("/") ? path : "/" + path
        return base + p
    }
}
