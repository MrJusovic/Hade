//
//  HTTPClient.swift
//  Hade
//
//  Ortam değişkeni ikamesi yaparak istek taslağını çalıştıran ağ katmanı.
//

import Foundation

/// İstek çalıştırılırken oluşabilecek hatalar.
enum HTTPClientError: LocalizedError {
    case invalidURL(String)
    case notHTTP

    var errorDescription: String? {
        switch self {
        case .invalidURL(let value):
            return "Geçersiz URL: \(value.isEmpty ? "(boş)" : value)"
        case .notHTTP:
            return "Yanıt bir HTTP yanıtı değil."
        }
    }
}

/// `{{değişken}}` sözdizimini verilen sözlükle değiştirir.
struct VariableResolver {
    let variables: [String: String]

    func resolve(_ input: String) -> String {
        guard !variables.isEmpty, input.contains("{{") else { return input }
        var result = input
        for (key, value) in variables {
            result = result.replacingOccurrences(of: "{{\(key)}}", with: value)
        }
        return result
    }
}

/// İstek taslağını gerçek bir ağ çağrısına dönüştürüp çalıştıran istemci.
struct HTTPClient {
    var session: URLSession = .shared

    func send(_ draft: RequestDraft, resolver: VariableResolver) async throws -> ResponseResult {
        let request = try makeURLRequest(from: draft, resolver: resolver)

        let clock = ContinuousClock()
        let start = clock.now
        let (data, response) = try await session.data(for: request)
        let elapsed = start.duration(to: clock.now)
        let ms = Double(elapsed.components.seconds) * 1000
            + Double(elapsed.components.attoseconds) / 1_000_000_000_000_000

        guard let http = response as? HTTPURLResponse else {
            throw HTTPClientError.notHTTP
        }

        let headers: [(String, String)] = http.allHeaderFields
            .compactMap { key, value in
                guard let key = key as? String else { return nil }
                return (key, "\(value)")
            }
            .sorted { $0.0.lowercased() < $1.0.lowercased() }

        return ResponseResult(
            statusCode: http.statusCode,
            statusText: HTTPURLResponse.localizedString(forStatusCode: http.statusCode).capitalized,
            headers: headers,
            body: data,
            durationMs: ms,
            finalURL: http.url?.absoluteString ?? request.url?.absoluteString ?? ""
        )
    }

    /// Taslaktan `URLRequest` üretir (ortam değişkenlerini uygulayarak).
    func makeURLRequest(from draft: RequestDraft, resolver: VariableResolver) throws -> URLRequest {
        let resolvedURL = resolver.resolve(draft.urlString).trimmingCharacters(in: .whitespacesAndNewlines)

        guard var components = URLComponents(string: resolvedURL), components.scheme != nil else {
            throw HTTPClientError.invalidURL(resolvedURL)
        }

        // Etkin query parametreleri tek kaynaktır: URL'deki query'yi bunlarla değiştir.
        // (Editördeki çift yönlü senkron, URL ile tabloyu zaten eşit tutar.)
        let activeQuery = draft.queryItems.filter { $0.enabled && !$0.key.isEmpty }
        if !activeQuery.isEmpty {
            components.queryItems = activeQuery.map {
                URLQueryItem(name: resolver.resolve($0.key), value: resolver.resolve($0.value))
            }
        }

        guard let url = components.url else {
            throw HTTPClientError.invalidURL(resolvedURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = draft.method.rawValue

        // Header'ları uygula.
        for header in draft.headers where header.enabled && !header.key.isEmpty {
            request.setValue(resolver.resolve(header.value), forHTTPHeaderField: resolver.resolve(header.key))
        }

        // Gövdeyi uygula.
        if draft.method.allowsBody {
            switch draft.bodyKind {
            case .none:
                break
            case .json:
                let text = resolver.resolve(draft.bodyText)
                request.httpBody = text.data(using: .utf8)
                if request.value(forHTTPHeaderField: "Content-Type") == nil {
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                }
            case .text:
                request.httpBody = resolver.resolve(draft.bodyText).data(using: .utf8)
                if request.value(forHTTPHeaderField: "Content-Type") == nil {
                    request.setValue("text/plain", forHTTPHeaderField: "Content-Type")
                }
            case .form:
                var components = URLComponents()
                components.queryItems = draft.formFields
                    .filter { $0.enabled && !$0.key.isEmpty }
                    .map { URLQueryItem(name: resolver.resolve($0.key), value: resolver.resolve($0.value)) }
                let encoded = components.percentEncodedQuery ?? ""
                request.httpBody = encoded.data(using: .utf8)
                if request.value(forHTTPHeaderField: "Content-Type") == nil {
                    request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
                }
            }
        }

        return request
    }
}
