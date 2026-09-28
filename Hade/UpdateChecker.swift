//
//  UpdateChecker.swift
//  Hade
//
//  GitHub Releases üzerinden güncelleme denetimi.
//

import Foundation

/// GitHub'daki en son sürüm bilgisi.
struct ReleaseInfo {
    var version: String
    var name: String
    var notes: String
    var url: URL
}

/// Güncelleme denetiminin durumu.
enum UpdateStatus {
    case idle
    case checking
    case upToDate
    case available(ReleaseInfo)
    case failed(String)
}

enum UpdateChecker {
    /// GitHub API'den en son sürümü çekip mevcut sürümle karşılaştırır.
    static func check() async -> UpdateStatus {
        var request = URLRequest(url: AppInfo.latestReleaseAPI)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode == 404 {
                return .failed("Henüz yayınlanmış bir sürüm bulunamadı.")
            }
            guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tag = object["tag_name"] as? String else {
                return .failed("Sürüm bilgisi okunamadı.")
            }
            let info = ReleaseInfo(
                version: tag,
                name: (object["name"] as? String)?.isEmpty == false ? (object["name"] as! String) : tag,
                notes: (object["body"] as? String) ?? "",
                url: URL(string: (object["html_url"] as? String) ?? "") ?? AppInfo.releasesURL
            )
            return isNewer(components(tag), than: components(AppInfo.version)) ? .available(info) : .upToDate
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    /// "v1.2.3" gibi bir sürümü [1, 2, 3] bileşenlerine ayırır.
    static func components(_ version: String) -> [Int] {
        version
            .trimmingCharacters(in: CharacterSet(charactersIn: "vV "))
            .split(separator: ".")
            .map { Int($0.prefix { $0.isNumber }) ?? 0 }
    }

    /// `a` sürümü `b`'den yeni mi?
    static func isNewer(_ a: [Int], than b: [Int]) -> Bool {
        for index in 0..<max(a.count, b.count) {
            let x = index < a.count ? a[index] : 0
            let y = index < b.count ? b[index] : 0
            if x != y { return x > y }
        }
        return false
    }
}
